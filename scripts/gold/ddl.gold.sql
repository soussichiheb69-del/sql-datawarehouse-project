/*
===============================================================================
GOLD LAYER - Data Warehouse (Star Schema)
===============================================================================
Script Purpose:
    Ce script crée les vues (VIEWS) de la couche Gold de l'entrepôt de
    données. La couche Gold constitue la couche de présentation métier :
    elle expose un modèle en étoile (Star Schema), composé de dimensions
    et d'une table de faits, prêt à être consommé par les outils de
    reporting, de BI et les analystes.

    Les vues de cette couche :
        - Intègrent et combinent les données nettoyées de la couche Silver.
        - Appliquent les dernières règles métier et transformations
          nécessaires à la restitution finale.
        - Génèrent des clés de substitution (surrogate keys) pour les
          dimensions, utilisées ensuite pour relier la table de faits
          aux dimensions.
        - Fournissent un modèle lisible, avec des noms de colonnes
          orientés métier plutôt que techniques.

Architecture (Medallion) :
    Bronze  -> Données brutes, telles que reçues des systèmes sources.
    Silver  -> Données nettoyées, standardisées et validées.
    Gold    -> Données modélisées en étoile, prêtes pour l'analyse (ce script).

Usage:
    Ces objets sont des VUES, et non des tables : elles ne stockent aucune
    donnée physiquement et reflètent en temps réel l'état de la couche
    Silver sous-jacente. Elles doivent être exécutées après le chargement
    complet de la couche Silver.

Convention de nommage :
    gold.dim_<entite>   -> Table de dimension
    gold.fact_<processus> -> Table de faits
===============================================================================
*/


/* ===============================================================================
   Vue : gold.dim_customers
   ===============================================================================
   Objectif :
       Fournir la dimension "Client", contenant les attributs descriptifs
       de chaque client, enrichis par les données CRM et ERP.

   Grain :
       Une ligne par client (cst_id).

   Sources :
       - silver.crm_cust_info   (source maître pour l'identité du client)
       - silver.erp_cust_az12   (données ERP : date de naissance, genre)
       - silver.erp_loc_a101    (données ERP : localisation / pays)

   Règles métier :
       - customer_key : clé de substitution générée via ROW_NUMBER(),
         indépendante des identifiants sources, utilisée comme clé
         primaire de la dimension et clé étrangère dans gold.fact_sales.
       - Genre (new_gen) : le CRM est considéré comme la source de vérité
         (master data). Si le CRM ne renseigne pas le genre ('n/a'),
         on se replie sur la valeur ERP (COALESCE), avec 'n/a' par défaut
         si aucune des deux sources n'est renseignée.
       - Jointures en LEFT JOIN : tous les clients du CRM sont conservés,
         même en l'absence de correspondance dans les tables ERP.
   =============================================================================== */
create view gold.dim_customers as
select
    row_number() over (order by cst_id)    as customer_key,       -- Clé de substitution (surrogate key)
    ci.cst_id                              as customer_id,        -- Identifiant client (système source CRM)
    ci.cst_key                             as customer_number,    -- Numéro client (clé métier / business key)
    ci.cst_first_name                      as first_name,
    ci.cst_lastname                        as last_name,
    la.cntry                               as country,            -- Pays du client (source ERP - localisation)
    ci.cst_material_status                 as marital_status,
    case when ci.cst_gndr != 'n/a' then ci.cst_gndr               -- CRM is the master for gender
         else coalesce(ca.gen, 'n/a')
    end                                     as new_gen,            -- Genre unifié (CRM prioritaire, ERP en secours)
    ca.bdate                               as birthdate,          -- Date de naissance (source ERP)
    ci.cst_create_date                     as create_date         -- Date de création du client dans le CRM
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca
    on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la
    on ci.cst_key = la.cid;
go


/* ===============================================================================
   Vue : gold.dim_products
   ===============================================================================
   Objectif :
       Fournir la dimension "Produit", incluant la catégorisation
       (catégorie / sous-catégorie) et les attributs de maintenance
       issus de l'ERP.

   Grain :
       Une ligne par produit actif (produit sans date de fin, c'est-à-dire
       la version actuelle du produit).

   Sources :
       - silver.crm_prd_info    (source maître pour les produits)
       - silver.erp_px_cat_g1v2 (données ERP : catégorie, sous-catégorie, maintenance)

   Règles métier :
       - product_key : clé de substitution générée via ROW_NUMBER(),
         ordonnée par date de début et clé produit, afin d'assurer un
         ordre stable et reproductible.
       - Filtre "prd_end_dt is null" : seules les versions actuelles
         (actives) des produits sont conservées ; l'historique des
         versions précédentes (SCD) est exclu de cette dimension.
       - Jointure en LEFT JOIN : tous les produits CRM sont conservés,
         même sans correspondance de catégorie côté ERP.
   =============================================================================== */
create view gold.dim_products as
select
    row_number() over (order by pn.prd_start_dt, pn.prd_key) as product_key,   -- Clé de substitution (surrogate key)
    pn.prd_id                              as product_id,          -- Identifiant produit (système source CRM)
    pn.prd_key                             as product_number,      -- Numéro produit (clé métier / business key)
    pn.prd_nm                              as product_name,
    pn.cat_id                              as category_id,
    pc.cat                                 as category,            -- Catégorie produit (source ERP)
    pc.subcat                              as subcategory,         -- Sous-catégorie produit (source ERP)
    pc.maintenance,                                                -- Indicateur de maintenance (source ERP)
    pn.prd_cost                            as cost,
    pn.prd_line                            as product_line,
    pn.prd_start_dt                        as start_date
from silver.crm_prd_info pn
left join silver.erp_px_cat_g1v2 pc
    on pn.cat_id = pc.id
where prd_end_dt is null;                                          -- Filter out all historical data
go


/* ===============================================================================
   Vue : gold.fact_sales
   ===============================================================================
   Objectif :
       Fournir la table de faits des ventes, au grain de la ligne de
       commande, reliée aux dimensions Client et Produit via leurs
       clés de substitution.

   Grain :
       Une ligne par ligne de commande (order_number x product_key).

   Sources :
       - silver.crm_sales_datails (transactions de vente issues du CRM)
       - gold.dim_products        (résolution de la clé produit)
       - gold.dim_customers       (résolution de la clé client)

   Règles métier :
       - Les clés étrangères (product_key, customer_key) sont résolues
         par jointure sur les clés métier (product_number, customer_id)
         des dimensions Gold, et non sur les identifiants sources bruts.
       - Jointures en LEFT JOIN : toutes les transactions de vente sont
         conservées, même en l'absence de correspondance dans les
         dimensions (les clés apparaîtront alors à NULL).
       - Cette vue ne contient aucune mesure calculée additionnelle :
         les métriques (sales_amount, quantity, price) sont reprises
         telles que nettoyées par la couche Silver.
   =============================================================================== */
create view gold.fact_sales as
select
    sd.sls_ord_num                         as order_number,
    pr.product_key,                                                -- Clé étrangère vers gold.dim_products
    cu.customer_key,                                                -- Clé étrangère vers gold.dim_customers
    sd.sls_order_dt                        as order_date,
    sd.sls_ship_dt                         as shipping_date,
    sd.sls_due_dt                          as due_date,
    sd.sls_sales                           as sales_amount,
    sd.sls_quantity                        as quantity,
    sd.sls_price                           as price
from silver.crm_sales_datails sd
left join gold.dim_products pr
    on sd.sls_prod_key = pr.product_number
left join gold.dim_customers cu
    on sd.sls_cust_id = cu.customer_id;
go
