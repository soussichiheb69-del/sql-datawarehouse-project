/*============================================================================
    SILVER LAYER - TABLE CREATION
    ==========================================================================
    Description :
        Ce script crée toutes les tables de la couche Silver du Data Warehouse.

    La couche Silver contient des données :
        - Nettoyées (Cleaned)
        - Standardisées (Standardized)
        - Prêtes pour les transformations métier (Business Ready)

    Processus appliqué à chaque table :
        1. Vérifier si la table existe.
        2. La supprimer si elle existe.
        3. La recréer avec la structure souhaitée.

    Remarque :
        Cette méthode est principalement utilisée pendant le développement afin
        d'éviter les conflits de structure entre différentes versions des tables.
============================================================================*/


/******************************************************************************
    TABLE : silver.crm_cust_info
    Description :
        Stocke les informations des clients provenant du système CRM.
******************************************************************************/

-- Vérifie si la table existe déjà ('U' = User Table).
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL

    -- Supprime la table existante avant sa recréation.
    DROP TABLE silver.crm_cust_info;

-- Création de la table.
CREATE TABLE silver.crm_cust_info (

    -- Identifiant unique du client.
    cst_id INT,

    -- Clé métier du client.
    cst_key NVARCHAR(50),

    -- Prénom du client.
    cst_first_name NVARCHAR(50),

    -- Nom du client.
    cst_lastname NVARCHAR(50),

    -- Statut matrimonial.
    cst_material_status NVARCHAR(50),

    -- Genre du client.
    cst_gndr NVARCHAR(50),

    -- Date de création du client dans le système source.
    cst_create_date DATE,

    -- Date de chargement dans le Data Warehouse.
    -- GETDATE() insère automatiquement la date et l'heure actuelles.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);



/******************************************************************************
    TABLE : silver.crm_prd_info
    Description :
        Stocke les informations des produits provenant du CRM.
******************************************************************************/

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;

CREATE TABLE silver.crm_prd_info (

    -- Identifiant du produit.
    prd_id INT,

    -- Identifiant de la catégorie.
    cat_id NVARCHAR(50),

    -- Clé métier du produit.
    prd_key NVARCHAR(50),

    -- Nom du produit.
    prd_nm NVARCHAR(50),

    -- Coût du produit.
    prd_cost INT,

    -- Ligne ou gamme du produit.
    prd_line NVARCHAR(50),

    -- Début de validité.
    prd_start_dt DATE,

    -- Fin de validité.
    prd_end_dt DATE,

    -- Date de chargement dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);



/******************************************************************************
    TABLE : silver.crm_sales_datails
    Description :
        Contient les transactions de vente provenant du CRM.
******************************************************************************/

IF OBJECT_ID('silver.crm_sales_datails', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_datails;

CREATE TABLE silver.crm_sales_datails (

    -- Numéro de commande.
    sls_ord_num NVARCHAR(50),

    -- Clé du produit vendu.
    sls_prod_key NVARCHAR(50),

    -- Identifiant du client.
    sls_cust_id INT,

    -- Date de commande.
    sls_order_dt DATE,

    -- Date d'expédition.
    sls_ship_dt DATE,

    -- Date limite de livraison.
    sls_due_dt DATE,

    -- Montant total de la vente.
    sls_sales INT,

    -- Quantité vendue.
    sls_quantity INT,

    -- Prix unitaire.
    sls_price INT,

    -- Date de chargement dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);



/******************************************************************************
    TABLE : silver.erp_loc_a101
    Description :
        Contient les informations géographiques des clients provenant de l'ERP.
******************************************************************************/

-- Vérifie si la table existe.
-- Remarque : le script original vérifie "bronze.erp_loc_a101" mais supprime
-- "silver.erp_loc_a101". Les deux schémas devraient être identiques.

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;

CREATE TABLE silver.erp_loc_a101 (

    -- Identifiant du client.
    cid NVARCHAR(50),

    -- Pays du client.
    cntry NVARCHAR(50),

    -- Date de chargement.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);



/******************************************************************************
    TABLE : silver.erp_cust_az12
    Description :
        Contient des informations complémentaires sur les clients ERP.
******************************************************************************/

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;

CREATE TABLE silver.erp_cust_az12 (

    -- Identifiant du client.
    cid NVARCHAR(50),

    -- Date de naissance.
    bdate DATE,

    -- Genre.
    gen NVARCHAR(50),

    -- Date de chargement.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);



/******************************************************************************
    TABLE : silver.erp_px_cat_g1v2
    Description :
        Table de référence des catégories de produits.
******************************************************************************/

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;

CREATE TABLE silver.erp_px_cat_g1v2 (

    -- Identifiant de la catégorie.
    id NVARCHAR(50),

    -- Catégorie principale.
    cat NVARCHAR(50),

    -- Sous-catégorie.
    subcat NVARCHAR(50),

    -- Type de maintenance.
    maintenance NVARCHAR(50),

    -- Date de chargement dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
