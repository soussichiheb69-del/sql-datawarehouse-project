/*
===============================================================================
QUALITY CHECKS - Gold Layer
===============================================================================
Script Purpose:
    Ce script effectue les contrôles qualité permettant de valider
    l'intégrité, l'unicité et la cohérence des vues de la couche Gold.
    Il vérifie notamment :
        - L'unicité des clés de substitution (surrogate keys) dans les
          tables de dimension.
        - L'intégrité référentielle entre la table de faits et les
          dimensions (aucune ligne de fait orpheline).
        - La cohérence des relations entre dimensions et faits, afin de
          garantir un modèle en étoile fiable pour le reporting et la BI.

Usage:
    - À exécuter après la création (ou le rafraîchissement) des vues
      de la couche Gold.
    - Chaque requête doit idéalement ne retourner AUCUNE ligne.
      Toute ligne retournée signale une anomalie à investiguer.
===============================================================================
*/


/* ===============================================================================
   Contrôle : gold.dim_customers - Unicité de la clé de substitution
   ===============================================================================
   Objectif :
       Vérifier que customer_key est unique pour chaque client, et donc
       qu'aucune duplication n'a été introduite par les jointures avec
       les tables ERP (erp_cust_az12, erp_loc_a101).

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    customer_key,
    count(*) as duplicate_count
from gold.dim_customers
group by customer_key
having count(*) > 1;


/* ===============================================================================
   Contrôle : gold.dim_customers - Doublons de clé métier (customer_id)
   ===============================================================================
   Objectif :
       Vérifier qu'un même customer_id (cst_id) n'apparaît pas plusieurs
       fois, ce qui indiquerait une cardinalité inattendue (1:N au lieu
       de 1:1) dans les jointures avec erp_cust_az12 ou erp_loc_a101.

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    customer_id,
    count(*) as duplicate_count
from gold.dim_customers
group by customer_id
having count(*) > 1;


/* ===============================================================================
   Contrôle : gold.dim_customers - Cohérence des valeurs de genre
   ===============================================================================
   Objectif :
       S'assurer que la colonne new_gen ne contient que des valeurs
       attendues (ex: 'M', 'F', 'n/a'), suite à la logique de repli
       CRM -> ERP.

   Résultat attendu :
       Uniquement les valeurs métier attendues ; aucune valeur inconnue
       ou NULL.
   =============================================================================== */
select distinct
    new_gen
from gold.dim_customers
order by new_gen;


/* ===============================================================================
   Contrôle : gold.dim_products - Unicité de la clé de substitution
   ===============================================================================
   Objectif :
       Vérifier que product_key est unique pour chaque produit actif,
       et donc qu'aucune duplication n'a été introduite par la jointure
       avec erp_px_cat_g1v2.

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    product_key,
    count(*) as duplicate_count
from gold.dim_products
group by product_key
having count(*) > 1;


/* ===============================================================================
   Contrôle : gold.dim_products - Doublons de clé métier (product_number)
   ===============================================================================
   Objectif :
       Vérifier qu'un même product_number (prd_key) n'apparaît pas
       plusieurs fois parmi les produits actifs (prd_end_dt is null),
       ce qui signalerait un problème de gestion d'historique (SCD)
       en amont, dans la couche Silver.

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    product_number,
    count(*) as duplicate_count
from gold.dim_products
group by product_number
having count(*) > 1;


/* ===============================================================================
   Contrôle : gold.fact_sales - Intégrité référentielle avec les dimensions
   ===============================================================================
   Objectif :
       Vérifier que chaque ligne de fait possède bien une clé produit
       et une clé client valides, correspondant à une ligne existante
       dans gold.dim_products et gold.dim_customers.

   Résultat attendu :
       Aucune ligne retournée (aucun fait orphelin, aucune clé NULL
       issue d'une jointure non résolue).
   =============================================================================== */
select
    f.order_number,
    f.product_key,
    f.customer_key
from gold.fact_sales f
left join gold.dim_products p
    on f.product_key = p.product_key
left join gold.dim_customers c
    on f.customer_key = c.customer_key
where p.product_key is null
   or c.customer_key is null;


/* ===============================================================================
   Contrôle : gold.fact_sales - Cohérence des mesures (sales = quantity * price)
   ===============================================================================
   Objectif :
       Vérifier que le montant des ventes correspond bien au produit
       de la quantité par le prix unitaire, et détecter les valeurs
       NULL, nulles ou négatives sur les mesures clés.

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    order_number,
    sales_amount,
    quantity,
    price
from gold.fact_sales
where sales_amount is null
   or quantity is null
   or price is null
   or sales_amount <= 0
   or quantity <= 0
   or price <= 0
   or sales_amount <> quantity * price;


/* ===============================================================================
   Contrôle : gold.fact_sales - Cohérence chronologique des dates
   ===============================================================================
   Objectif :
       Vérifier que la date de commande précède toujours la date
       d'expédition et la date d'échéance.

   Résultat attendu :
       Aucune ligne retournée.
   =============================================================================== */
select
    order_number,
    order_date,
    shipping_date,
    due_date
from gold.fact_sales
where order_date > shipping_date
   or order_date > due_date;
