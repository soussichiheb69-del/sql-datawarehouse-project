/*
===============================================================================
Quality Checks : Silver Layer
===============================================================================
Objectif :
    Ce script contient une série de contrôles qualité exécutés APRÈS le
    chargement de la couche 'silver' (voir silver.load_silver), afin de
    vérifier :
        - L'unicité des clés primaires
        - L'absence d'espaces superflus non nettoyés
        - La cohérence et la standardisation des valeurs (domaines attendus)
        - La cohérence des dates (ordre chronologique, dates futures)
        - La cohérence des calculs (ex : sls_sales = sls_quantity * sls_price)

Utilisation :
    - Exécuter ce script après chaque exécution de silver.load_silver
    - Chaque requête doit retourner un jeu de résultats VIDE (0 ligne)
      si les données sont conformes. Toute ligne retournée signale une
      anomalie à investiguer.
===============================================================================
*/

-- ===============================================================================
-- Table : silver.crm_cust_info
-- ===============================================================================

-- Contrôle 1 : Unicité de la clé primaire (cst_id)
-- Attendu : aucune ligne retournée (pas de doublons, pas de NULL)
select 
    cst_id,
    count(*) as nb_occurrences
from silver.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null;

-- Contrôle 2 : Espaces superflus non nettoyés sur les noms
-- Attendu : aucune ligne retournée
select cst_first_name
from silver.crm_cust_info
where cst_first_name != trim(cst_first_name);

select cst_lastname
from silver.crm_cust_info
where cst_lastname != trim(cst_lastname);

-- Contrôle 3 : Cohérence du domaine des valeurs standardisées
-- Attendu : uniquement 'Single', 'Married', 'n/a'
select distinct cst_material_status
from silver.crm_cust_info;

-- Attendu : uniquement 'Female', 'Male', 'n/a'
select distinct cst_gndr
from silver.crm_cust_info;


-- ===============================================================================
-- Table : silver.crm_prd_info
-- ===============================================================================

-- Contrôle 1 : Unicité de la clé primaire (prd_id)
-- Attendu : aucune ligne retournée
select 
    prd_id,
    count(*) as nb_occurrences
from silver.crm_prd_info
group by prd_id
having count(*) > 1 or prd_id is null;

-- Contrôle 2 : Espaces superflus non nettoyés sur le nom du produit
-- Attendu : aucune ligne retournée
select prd_nm
from silver.crm_prd_info
where prd_nm != trim(prd_nm);

-- Contrôle 3 : Coût produit NULL ou négatif
-- Attendu : aucune ligne retournée
select prd_cost
from silver.crm_prd_info
where prd_cost is null or prd_cost < 0;

-- Contrôle 4 : Cohérence du domaine des valeurs standardisées
-- Attendu : uniquement 'Mountain', 'Road', 'Other Sales', 'Touring', 'n/a'
select distinct prd_line
from silver.crm_prd_info;

-- Contrôle 5 : Cohérence chronologique (la date de fin doit être
-- postérieure ou égale à la date de début)
-- Attendu : aucune ligne retournée
select *
from silver.crm_prd_info
where prd_end_dt < prd_start_dt;


-- ===============================================================================
-- Table : silver.crm_sales_datails
-- ===============================================================================

-- Contrôle 1 : Dates invalides (hors plage raisonnable ou incohérentes
-- entre elles : commande postérieure à expédition ou à échéance)
-- Attendu : aucune ligne retournée
select *
from silver.crm_sales_datails
where sls_order_dt > sls_ship_dt
   or sls_order_dt > sls_due_dt;

-- Contrôle 2 : Cohérence sls_sales = sls_quantity * sls_price
-- Attendu : aucune ligne retournée (aucune valeur NULL, nulle,
-- négative ou incohérente avec quantité * prix)
select 
    sls_sales,
    sls_quantity,
    sls_price
from silver.crm_sales_datails
where sls_sales != sls_quantity * sls_price
   or sls_sales is null or sls_quantity is null or sls_price is null
   or sls_sales <= 0 or sls_quantity <= 0 or sls_price <= 0;


-- ===============================================================================
-- Table : silver.erp_cust_az12
-- ===============================================================================

-- Contrôle 1 : Dates de naissance hors plage raisonnable
-- (trop anciennes ou dans le futur)
-- Attendu : aucune ligne retournée
select distinct bdate
from silver.erp_cust_az12
where bdate < '1924-01-01' or bdate > getdate();

-- Contrôle 2 : Cohérence du domaine des valeurs standardisées
-- Attendu : uniquement 'Female', 'Male', 'n/a'
select distinct gen
from silver.erp_cust_az12;


-- ===============================================================================
-- Table : silver.erp_loc_a101
-- ===============================================================================

-- Contrôle : Cohérence du domaine des pays standardisés
-- Attendu : liste finie et propre de pays (ex : 'Germany',
-- 'United States', 'n/a', ...), sans variantes non normalisées
select distinct cntry
from silver.erp_loc_a101
order by cntry;


-- ===============================================================================
-- Table : silver.erp_px_cat_g1v2
-- ===============================================================================

-- Contrôle 1 : Espaces superflus non nettoyés
-- Attendu : aucune ligne retournée
select *
from silver.erp_px_cat_g1v2
where cat != trim(cat)
   or subcat != trim(subcat)
   or maintenance != trim(maintenance);

-- Contrôle 2 : Cohérence du domaine des valeurs (maintenance)
-- Attendu : liste finie de valeurs attendues (ex : 'Yes', 'No')
select distinct maintenance
from silver.erp_px_cat_g1v2;
