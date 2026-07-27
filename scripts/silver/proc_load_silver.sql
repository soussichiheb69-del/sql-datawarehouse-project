/*
===============================================================================
Stored Procedure : silver.load_silver
===============================================================================
Objectif :
    Cette procédure stockée exécute le processus ETL (Extract, Transform, Load)
    permettant de peupler les tables du schéma 'silver' à partir des données
    brutes du schéma 'bronze', dans le cadre d'une architecture de type
    Médaillon (Bronze -> Silver -> Gold).

Actions réalisées :
    1. Vide (TRUNCATE) les tables Silver avant chaque chargement, afin de
       garantir un rechargement complet et propre (stratégie "Full Load").
    2. Insère les données transformées et nettoyées (INSERT) issues du
       schéma Bronze vers le schéma Silver.
    3. Applique des règles de nettoyage, standardisation et déduplication
       propres à chaque table source (CRM et ERP).

Paramètres :
    Aucun. Cette procédure ne prend aucun paramètre en entrée et ne retourne
    aucune valeur.

Exemple d'exécution :
    EXEC silver.load_silver;

Remarques :
    - Le bloc TRY...CATCH capture toute erreur survenant pendant le
      chargement et affiche le message, le numéro et l'état de l'erreur,
      sans interrompre brutalement la session.
    - Les durées de chargement (en secondes) sont affichées pour chaque
      table via PRINT, ce qui facilite le suivi et le débogage du batch.
===============================================================================
*/

create or alter procedure silver.load_silver as
begin
	-- Variables utilisées pour mesurer la durée de chargement
	-- de chaque table (@start_time / @end_time) et du batch complet
	-- (@batch_start_time / @batch_end_time)
	declare @start_time datetime, @end_time datetime, @batch_start_time datetime, @batch_end_time datetime;

	begin try 
		set @batch_start_time = getdate();
		print '============================================';
		print 'Loading Silver Layer';
		print '============================================';

		print '--------------------------------------------';
		print 'Loading CRM Tables';
		print '--------------------------------------------';

		-- ===========================================================
		-- Table : silver.crm_cust_info
		-- Source : bronze.crm_cust_info
		-- Règles de nettoyage appliquées :
		--   - Suppression des espaces superflus (TRIM) sur le prénom
		--     et le nom du client
		--   - Standardisation du statut matrimonial (S -> Single,
		--     M -> Married, valeur inconnue -> 'n/a')
		--   - Standardisation du genre (F -> Female, M -> Male,
		--     valeur inconnue -> 'n/a')
		--   - Déduplication : pour un même cst_id, seule la ligne la
		--     plus récente (cst_create_date la plus élevée) est
		--     conservée, via ROW_NUMBER() OVER (PARTITION BY cst_id
		--     ORDER BY cst_create_date DESC)
		--   - Exclusion des lignes où cst_id est NULL
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.crm_cust_info';
		truncate table silver.crm_cust_info;
		print '>> Inserting Data Into: silver.crm_cust_info';
		insert into silver.crm_cust_info(
				cst_id,
				cst_key,
				cst_first_name,
				cst_lastname,
				cst_material_status,
				cst_gndr,
				cst_create_date)
		select
				cst_id,
				cst_key,
				trim(cst_first_name) as cst_firstname,
				trim(cst_lastname) as cst_lastname,

				-- Normalisation du code statut matrimonial en libellé complet
				case when upper(trim(cst_material_status)) = 'S' then 'Single'
					 when upper(trim(cst_material_status)) = 'M' then 'Married'
					 else 'n/a'
				end cst_marital_status,

				-- Normalisation du code genre en libellé complet
				case when upper(trim(cst_gndr)) = 'F' then 'Female'
					 when upper(trim(cst_gndr)) = 'M' then 'Male'
					 else 'n/a'
				end cst_gndr,
				cst_create_date
			from (
					-- Sous-requête : on numérote les enregistrements par client
					-- (cst_id) du plus récent au plus ancien, afin de ne
					-- garder que la dernière version de chaque client
					select
					*,
					row_number() over (partition by cst_id order by cst_create_date desc) as flag_last
					from bronze.crm_cust_info
					where cst_id is not null
				)t where flag_last = 1
		set @end_time = getdate();
		print '>> load duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'seconds';
		print'>> -------------';

		-- ===========================================================
		-- Table : silver.crm_prd_info
		-- Source : bronze.crm_prd_info
		-- Règles de nettoyage appliquées :
		--   - Extraction de l'identifiant catégorie (cat_id) à partir
		--     des 5 premiers caractères de prd_key, en remplaçant les
		--     tirets '-' par des underscores '_' (pour correspondre à
		--     la clé utilisée dans la table des catégories ERP)
		--   - Extraction de la clé produit "métier" réelle (prd_key)
		--     à partir du reste de la chaîne (à partir du 7e caractère)
		--   - Remplacement des coûts NULL par 0 (ISNULL)
		--   - Standardisation de la ligne produit (prd_line) en
		--     libellé complet (M -> Mountain, R -> Road, S -> Other
		--     Sales, T -> Touring, sinon 'n/a')
		--   - Calcul de la date de fin de validité du produit
		--     (prd_end_dt) : correspond à la date de début du
		--     prochain enregistrement du même produit moins 1 jour,
		--     via la fonction fenêtrée LEAD() OVER (PARTITION BY
		--     prd_key ORDER BY prd_start_dt). Cela permet de recréer
		--     un historique de validité cohérent (type SCD2) même si
		--     la source ne fournit pas cette date explicitement
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.crm_prd_info';
		truncate table silver.crm_prd_info;
		print '>> Inserting Data Into: silver.crm_prd_info';
		insert into silver.crm_prd_info (
				prd_id,
				cat_id,
				prd_key,
				prd_nm,
				prd_cost,
				prd_line,
				prd_start_dt,
				prd_end_dt
			)

		select 
				prd_id,
				replace(substring(prd_key, 1, 5), '-', '_') as cat_id,
				substring(prd_key, 7, len(prd_key)) as prd_key,
				prd_nm,
				isnull(prd_cost,0) as prd_cost,
				case upper(trim(prd_line)) 
					 when 'M' then 'Mountain'
					 when 'R' then 'Road'
					 when 'S' then 'Other Sales'
					 when 'T' then 'Touring'
					 else 'n/a'
				end as prd_line,
				cast(prd_start_dt as date) as prd_start_dt,
				-- Date de fin = date de début du produit suivant - 1 jour
				cast(lead(prd_start_dt) over (partition by prd_key order by prd_start_dt) - 1 as date) as prd_end_dt
		from bronze.crm_prd_info
		set @end_time = getdate();
		print '>> load duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'seconds';
		print'>> -------------';

		-- ===========================================================
		-- Table : silver.crm_sales_datails
		-- Source : bronze.crm_sales_datails
		-- Règles de nettoyage appliquées :
		--   - Validation des dates (order/ship/due) : si la valeur
		--     source vaut 0 ou ne contient pas exactement 8 caractères
		--     (format attendu AAAAMMJJ), la date est mise à NULL ;
		--     sinon elle est convertie en type DATE
		--   - Recalcul de sls_sales si la valeur source est NULL,
		--     négative/nulle, ou incohérente avec quantité x prix
		--     (contrôle de cohérence sls_sales = sls_quantity *
		--     ABS(sls_price))
		--   - Recalcul de sls_price si la valeur source est NULL ou
		--     négative/nulle, en la dérivant de sls_sales / sls_quantity
		--     (NULLIF évite une division par zéro)
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.crm_sales_datails';
		truncate table silver.crm_sales_datails;
		print '>> Inserting Data Into: silver.crm_sales_datails';
		insert into silver.crm_sales_datails(
				sls_ord_num,
				sls_prod_key,
				sls_cust_id,
				sls_order_dt,
				sls_ship_dt,
				sls_due_dt,
				sls_sales,
				sls_quantity,
				sls_price
			)
		select
				sls_ord_num,
				sls_prod_key,
				sls_cust_id,
				-- Conversion sécurisée de la date de commande
				case when sls_order_dt = 0 or len(sls_order_dt) !=8 then null
					 else cast(cast(sls_order_dt as varchar) as date)
				end as sls_order_dt,
				-- Conversion sécurisée de la date d'expédition
				case when sls_ship_dt = 0 or len(sls_ship_dt) !=8 then null
					 else cast(cast(sls_ship_dt as varchar) as date)
				end as sls_ship_dt,
				-- Conversion sécurisée de la date d'échéance
				case when sls_due_dt = 0 or len(sls_due_dt) !=8 then null
					 else cast(cast(sls_due_dt as varchar) as date)
				end as sls_due_dt,
				-- Recalcul du montant des ventes si valeur manquante,
				-- négative ou incohérente avec quantité * prix
				case when sls_sales is null or sls_sales <= 0 or sls_sales != sls_quantity * abs(sls_price)
					 then  sls_quantity * abs(sls_price)
				end as sls_sales,
				sls_quantity,
				-- Recalcul du prix unitaire si valeur manquante ou négative
				case when sls_price is null or sls_price <= 0 
						then sls_sales / nullif(sls_quantity,0)
					 else sls_price
				end as sls_price
		from bronze.crm_sales_datails
		set @end_time = getdate();
		print '>> load duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'seconds';
		print'>> -------------';

		print '--------------------------------------------';
		print 'Loading ERP Tables';
		print '--------------------------------------------';

		-- ===========================================================
		-- Table : silver.erp_loc_a101
		-- Source : bronze.erp_loc_a101
		-- Règles de nettoyage appliquées :
		--   - Suppression des tirets '-' dans l'identifiant client
		--     (cid) afin de l'aligner avec le format utilisé dans les
		--     autres tables clients
		--   - Standardisation des codes pays (DE -> Germany,
		--     US/USA -> United States, valeur vide ou NULL -> 'n/a',
		--     sinon la valeur nettoyée telle quelle)
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.erp_loc_a101';
		truncate table silver.erp_loc_a101;
		print '>> Inserting Data Into: silver.erp_loc_a101';
		insert into silver.erp_loc_a101(cid, cntry)
		select 
				replace(cid, '-', '') cid,
				case when trim(cntry) = 'DE' then 'Germany'
					 when trim(cntry) in ('US','USA') then 'United States'
					 when trim(cntry) = '' or cntry is null then 'n/a'
					 else trim(cntry)
				end as cntry
		from bronze.erp_loc_a101;
		set @end_time = getdate();
		print '>> load duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'seconds';
		print'>> -------------';

		-- ===========================================================
		-- Table : silver.erp_px_cat_g1v2
		-- Source : bronze.erp_px_cat_g1v2
		-- Règles de nettoyage appliquées :
		--   - Aucune transformation nécessaire : les données source
		--     (catégorie, sous-catégorie, indicateur de maintenance)
		--     sont déjà propres et sont chargées telles quelles
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.erp_px_cat_g1v2';
		truncate table silver.erp_px_cat_g1v2;
		print '>> Inserting Data Into: silver.erp_cat_g1v2';
		insert into silver.erp_px_cat_g1v2(
				id,
				cat,
				subcat,
				maintenance
			)
		select
				id,
				cat,
				subcat,
				maintenance
		from bronze.erp_px_cat_g1v2
		set @end_time = getdate();
		print '>> load duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'seconds';
		print'>> -------------';

		-- ===========================================================
		-- Table : silver.erp_cust_az12
		-- Source : bronze.erp_cust_az12
		-- Règles de nettoyage appliquées :
		--   - Suppression du préfixe 'NAS' dans l'identifiant client
		--     (cid) lorsqu'il est présent, afin de l'aligner sur le
		--     format des autres tables clients (CRM)
		--   - Invalidation des dates de naissance (bdate) futures
		--     (postérieures à la date système), remplacées par NULL
		--   - Standardisation du genre (F/Female -> Female,
		--     M/Male -> Male, valeur inconnue -> 'n/a')
		-- ===========================================================
		set @start_time = getdate();
		print '>> Truncating Table:	silver.erp_cust_az12';
		truncate table silver.erp_cust_az12;
		print '>> Inserting Data Into: silver.erp_cust_az12';
		insert into silver.erp_cust_az12 (cid, bdate, gen)

		select
				-- Suppression du préfixe 'NAS' si présent en début de cid
				case when cid like 'NAS%' then substring(cid, 4, len(cid))
					 else cid
				end as cid,
				-- Une date de naissance future est considérée comme invalide
				case when bdate > getdate() then null
					 else bdate
				end as bdate,
				case when upper(trim(gen)) in ('F', 'Female') then 'Female'
					 when upper(trim(gen)) in ('M','Male') then 'Male'
					 else 'n/a'
				end as gen
		from bronze.erp_cust_az12 
		set @batch_end_time = getdate();
		print '==============================================';
		print 'Loading Silver Layer is Completed ';
		print '   -Total Load Duration ' + cast(datediff(second, @batch_start_time , @batch_end_time) as nvarchar ) + 'seconds';
		print '==============================================';
	end try
	begin catch
		-- Gestion centralisée des erreurs : affiche le message,
		-- le numéro et l'état de l'erreur SQL Server sans interrompre
		-- brutalement l'exécution de la session appelante
		print '====================================='
		print 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		print 'Error Message' + error_message();
		print 'Error Message' + cast(error_number() as nvarchar);
		print 'Error Message' + cast(error_state() as nvarchar);
		print '=====================================';
	end catch
end
