/* Description   :
 *   Ce script initialise l'environnement du Data Warehouse en :
 *     1. Vérifiant si une ancienne base existe.
 *     2. Fermant toutes les connexions actives.
 *     3. Supprimant l'ancienne base de données.
 *     4. Créant une nouvelle base de données.
 *     5. Créant les schémas Bronze, Silver et Gold.
  Warning:
      Running this script will drop the entire 'Datawarehouse' datbase if it exists.
      All data in the database will be permanently deleted. Proceed with caution
      and ensure you have backups before running this script*/
-- Se connecter à la base système "master".
-- Cette étape est obligatoire car une base de données ne peut pas être supprimée
-- lorsqu'elle est utilisée par la session courante.
USE master;
GO

-- Vérifier si la base de données "DataWarehouse" existe déjà.
IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE name = 'DataWarehouse')
BEGIN

    -- Passer la base en mode SINGLE_USER.
    -- Cette opération force la fermeture de toutes les connexions actives
    -- afin d'autoriser sa suppression.
    ALTER DATABASE DataWarehouse
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    -- Supprimer complètement l'ancienne base de données.
    DROP DATABASE DataWarehouse;
END;

-- Suppression conditionnelle (compatible SQL Server 2016+).
-- Cette instruction garantit qu'aucune ancienne base ne subsiste.
DROP DATABASE IF EXISTS DataWarehouse;

-- Création de la nouvelle base de données décisionnelle.
CREATE DATABASE DataWarehouse;

-- Sélectionner la nouvelle base afin d'y créer les différents objets.
USE DataWarehouse;
GO

/**********************************************************************************************
 * Création des schémas fonctionnels du Data Warehouse
 **********************************************************************************************/

-- ============================================================================================
-- Schéma BRONZE
-- --------------------------------------------------------------------------------------------
-- Première couche du Data Warehouse (Landing Zone / Staging Area).
-- Contient les données extraites des différentes sources sans transformation.
-- Objectif :
--   • Conserver les données dans leur format d'origine.
--   • Garantir la traçabilité des chargements.
--   • Servir de point d'entrée au processus ETL.
-- ============================================================================================
CREATE SCHEMA bronze;
GO

-- ============================================================================================
-- Schéma SILVER
-- --------------------------------------------------------------------------------------------
-- Deuxième couche du Data Warehouse.
-- Contient les données nettoyées, transformées et harmonisées.
-- Les traitements réalisés peuvent inclure :
--   • Suppression des doublons.
--   • Correction des incohérences.
--   • Standardisation des formats.
--   • Validation de la qualité des données.
-- ============================================================================================
CREATE SCHEMA silver;
GO

-- ============================================================================================
-- Schéma GOLD
-- --------------------------------------------------------------------------------------------
-- Couche finale destinée à l'analyse décisionnelle.
-- Contient les tables de faits, dimensions, agrégations et indicateurs
-- directement exploités par les outils de Business Intelligence (Power BI,
-- Tableau, SSRS, etc.).
-- ============================================================================================
CREATE SCHEMA gold;
GO

/**********************************************************************************************
 * Fin de la phase 1 : Initialisation du Data Warehouse
 *
 * Résultat :
 *   ✓ Base de données DataWarehouse créée.
 *   ✓ Schéma Bronze créé.
 *   ✓ Schéma Silver créé.
 *   ✓ Schéma Gold créé.
 *
 * Le Data Warehouse est désormais prêt à recevoir les données sources.
 **********************************************************************************************/
