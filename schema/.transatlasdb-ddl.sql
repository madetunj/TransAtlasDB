-- MySQL Script
-- 
-- Host: localhost    Database: transatlasdb
-- Model: TransAtlasDB		Version: 2.0
-- Function: TransAtlasDB Schema Script
-- 
-- ---------------------------------------------------
-- Server version	5.5.53
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
-- -----------------------------------------------------
-- Drop all tables if exists (23 tables)
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Person`;
DROP TABLE IF EXISTS `SamplePerson`;
DROP TABLE IF EXISTS `SampleOrganization`;
DROP TABLE IF EXISTS `Organization`;
DROP TABLE IF EXISTS `Material`;
DROP TABLE IF EXISTS `Organism`;
DROP TABLE IF EXISTS `Sex`;
DROP TABLE IF EXISTS `HealthStatus`;
DROP TABLE IF EXISTS `Breed`;
DROP TABLE IF EXISTS `Tissue`;
DROP TABLE IF EXISTS `DevelopmentalStage`;
DROP TABLE IF EXISTS `Animal`;
DROP TABLE IF EXISTS `AnimalStats`;
DROP TABLE IF EXISTS `Sample`;
DROP TABLE IF EXISTS `SampleStats`;
DROP TABLE IF EXISTS `MapStats`;
DROP TABLE IF EXISTS `GeneStats`;
DROP TABLE IF EXISTS `Metadata`;
DROP TABLE IF EXISTS `VarSummary`;
DROP TABLE IF EXISTS `CommandSyntax`;
DROP TABLE IF EXISTS `VarResult`;
DROP TABLE IF EXISTS `VarAnnotation`;
-- -----------------------------------------------------
-- Table structure for table `Person`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Person`;
CREATE TABLE `Person` (`personid` VARCHAR(200) NOT NULL,`lastname` TEXT NOT NULL, `middleinitial` TEXT NOT NULL, `firstname` TEXT NOT NULL, `email` TEXT NULL DEFAULT NULL, `role` TEXT NULL DEFAULT NULL, PRIMARY KEY (`personid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `SamplePerson`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `SamplePerson`;
CREATE TABLE `SamplePerson` (`sampleid` VARCHAR(150) NOT NULL,`personid` VARCHAR(200) NOT NULL, PRIMARY KEY (`personid`, `sampleid`), CONSTRAINT `sampleperson_person_ibfk_1` FOREIGN KEY (`personid`) REFERENCES `Person` (`personid`), CONSTRAINT `sampleperson_sample_ibfk_2` FOREIGN KEY (`sampleid`) REFERENCES `Sample` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `SampleOrganization`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `SampleOrganization`;
CREATE TABLE `SampleOrganization` (`sampleid` VARCHAR(150) NOT NULL, `organizationname` VARCHAR(300) NOT NULL,PRIMARY KEY (`organizationname`, `sampleid`), CONSTRAINT `sampleorganization_organization_ibfk_1` FOREIGN KEY (`organizationname`) REFERENCES `Organization` (`organizationname`), CONSTRAINT `sampleorganization_sample_ibfk_2` FOREIGN KEY (`sampleid`) REFERENCES `Sample` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Organization`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Organization`;
CREATE TABLE `Organization` (`organizationname` VARCHAR(300) NOT NULL, `address` TEXT NULL DEFAULT NULL, `URL` TEXT NULL DEFAULT NULL, `role` TEXT NULL DEFAULT NULL, PRIMARY KEY (`organizationname`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Material`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Material`;
CREATE TABLE `Material` (`material` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`material`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Organism`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Organism`;
CREATE TABLE `Organism` (`organism` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`organism`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Sex`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Sex`;
CREATE TABLE `Sex` (`sex` VARCHAR(50) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`sex`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `HealthStatus`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `HealthStatus`;
CREATE TABLE `HealthStatus` (`health` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`health`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Breed`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Breed`;
CREATE TABLE `Breed` (`breed` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`breed`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Tissue`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Tissue`;
CREATE TABLE `Tissue` (`tissue` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`tissue`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `DevelopmentalStage`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `DevelopmentalStage`;
CREATE TABLE `DevelopmentalStage` (`developmentalstage` VARCHAR(150) NOT NULL, `termref` VARCHAR(50) NULL DEFAULT NULL, `termid` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`developmentalstage`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Animal`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Animal`;
CREATE TABLE `Animal` (`animalid` VARCHAR(150) NOT NULL, `project` VARCHAR(100) NULL DEFAULT NULL, `material` VARCHAR(150) NULL DEFAULT NULL, `organism` VARCHAR(150) NOT NULL, `sex` VARCHAR(50) NULL DEFAULT NULL, `health` VARCHAR(150) NULL DEFAULT NULL, `breed` VARCHAR(150) NULL DEFAULT NULL, `description` TEXT NULL DEFAULT NULL, PRIMARY KEY (`animalid`, `organism`), CONSTRAINT `animal_material_ibfk_1` FOREIGN KEY (`material`) REFERENCES `Material` (`material`), CONSTRAINT `animal_organism_ibfk_2` FOREIGN KEY (`organism`) REFERENCES `Organism` (`organism`), CONSTRAINT `animal_sex_ibfk_3` FOREIGN KEY (`sex`) REFERENCES `Sex` (`sex`), CONSTRAINT `animal_health_ibfk_4` FOREIGN KEY (`health`) REFERENCES `HealthStatus` (`health`), CONSTRAINT `animal_breed_ibfk_5` FOREIGN KEY (`breed`) REFERENCES `Breed` (`breed`), INDEX `animal_indx_organism` (`organism` ASC)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `AnimalStats`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `AnimalStats`;
CREATE TABLE `AnimalStats` (`animalid` VARCHAR(150) NOT NULL, `birthdate` TEXT NULL DEFAULT NULL, `birthlocation` TEXT NULL DEFAULT NULL, `birthloclatitude` TEXT NULL DEFAULT NULL, `birthloclongitude` TEXT NULL DEFAULT NULL, `birthweight` TEXT NULL DEFAULT NULL, `placentalweight` TEXT NULL DEFAULT NULL, `pregnancylength` TEXT NULL DEFAULT NULL, `deliveryease` TEXT NULL DEFAULT NULL, `deliverytiming` TEXT NULL DEFAULT NULL,`pedigree` TEXT NULL DEFAULT NULL, PRIMARY KEY (`animalid`), CONSTRAINT `animalstats_ibfk_1` FOREIGN KEY (`animalid`) REFERENCES `Animal` (`animalid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Sample`;
CREATE TABLE `Sample` (`sampleid` VARCHAR(150) NOT NULL,`project` VARCHAR(100) NULL DEFAULT NULL, `material` VARCHAR(150) NULL DEFAULT NULL, `tissue` VARCHAR(150) NULL DEFAULT NULL,`derivedfrom` VARCHAR(150) NULL DEFAULT NULL,`availability` TEXT NULL DEFAULT NULL, `developmentalstage` VARCHAR(150) NULL DEFAULT NULL, `health` VARCHAR(150) NULL DEFAULT NULL, `description` TEXT NULL DEFAULT NULL,`date` DATE NULL DEFAULT NULL, PRIMARY KEY (`sampleid`), CONSTRAINT `sample_animal_ibfk_1` FOREIGN KEY (`derivedfrom`) REFERENCES `Animal` (`animalid`), CONSTRAINT `sample_material_ibfk_2` FOREIGN KEY (`material`) REFERENCES `Material` (`material`), CONSTRAINT `sample_tissue_ibfk_3` FOREIGN KEY (`tissue`) REFERENCES `Tissue` (`tissue`), CONSTRAINT `sample_dvplstage_ibfk_4` FOREIGN KEY (`developmentalstage`) REFERENCES `DevelopmentalStage` (`developmentalstage`), CONSTRAINT `sample_health_ibfk_5` FOREIGN KEY (`health`) REFERENCES `HealthStatus` (`health`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `SampleStats`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `SampleStats`;
CREATE TABLE `SampleStats` (`sampleid` VARCHAR(150) NOT NULL, `collectionprotocol` TEXT NULL DEFAULT NULL, `collectiondate` TEXT NULL DEFAULT NULL, `ageatcollection` TEXT NULL DEFAULT NULL, `fastedstatus`	TEXT NULL DEFAULT NULL, `noofpieces` TEXT NULL DEFAULT NULL, `specimenvol` TEXT NULL DEFAULT NULL, `specimensize`	TEXT NULL DEFAULT NULL, `specimenwgt` TEXT NULL DEFAULT NULL, `specimenpictureurl` TEXT NULL DEFAULT NULL, `gestationalage` TEXT NULL DEFAULT NULL, PRIMARY KEY (`sampleid`), CONSTRAINT `samplestats_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `Sample` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `MapStats`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `MapStats`;
CREATE TABLE `MapStats` (`sampleid` VARCHAR(150) NOT NULL, `totalreads` INT(11) NULL DEFAULT NULL, `mappedreads` INT(11) NULL DEFAULT NULL, `alignmentrate` DOUBLE(5,2) NULL DEFAULT NULL, `deletions` INT(11) NULL DEFAULT NULL, `insertions` INT(11) NULL DEFAULT NULL, `junctions` INT(11) NULL DEFAULT NULL, `date` DATE NULL DEFAULT NULL, PRIMARY KEY (`sampleid`), CONSTRAINT `MapStats_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `Sample` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `GeneStats`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `GeneStats`;
CREATE TABLE `GeneStats` (`sampleid` VARCHAR(150) NOT NULL, `genes` INT(11) NULL DEFAULT NULL, `diffexpresstool` VARCHAR(100) NULL DEFAULT NULL, `countstool` VARCHAR(100) NULL DEFAULT NULL, `date` DATE NULL DEFAULT NULL, `countstatus` CHAR(10) NULL, `genestatus` CHAR(10) NULL,PRIMARY KEY (`sampleid`), CONSTRAINT `GeneStats_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `MapStats` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `Metadata`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Metadata`;
CREATE TABLE `Metadata` ( `sampleid` VARCHAR(150) NOT NULL, `refgenome` VARCHAR(100) NULL DEFAULT NULL, `annfile` VARCHAR(50) NULL DEFAULT NULL, `stranded` VARCHAR(100) NULL DEFAULT NULL, `sequencename` TEXT NULL DEFAULT NULL, `mappingtool` VARCHAR(100) NULL DEFAULT NULL, CONSTRAINT `metadata_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `MapStats` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `CommandSyntax`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `CommandSyntax`;
CREATE TABLE `CommandSyntax` ( `sampleid` VARCHAR(150) NOT NULL, `mappingsyntax` TEXT NULL DEFAULT NULL, `expressionsyntax` TEXT NULL DEFAULT NULL, `countsyntax` TEXT NULL DEFAULT NULL, `variantsyntax` TEXT NULL DEFAULT NULL, CONSTRAINT `commandsyntax_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `MapStats` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `VarSummary`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `VarSummary`;
CREATE TABLE `VarSummary` (`sampleid` VARCHAR(150) NOT NULL, `totalvariants` INT(11) NULL DEFAULT NULL, `totalsnps` INT(11) NULL DEFAULT NULL, `totalindels` INT(11) NULL DEFAULT NULL, `annversion` VARCHAR(100) NULL DEFAULT NULL, `varianttool` VARCHAR(100) NULL DEFAULT NULL, `date` DATE NOT NULL, `status` CHAR(10) NULL DEFAULT NULL, `nosql` CHAR(10) NULL DEFAULT NULL, PRIMARY KEY (`sampleid`), CONSTRAINT `varsummary_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `MapStats` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `VarResult`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `VarResult`;
CREATE TABLE `VarResult` ( `sampleid` VARCHAR(150) NOT NULL, `chrom` VARCHAR(100) NOT NULL DEFAULT '', `position` INT(11) NOT NULL DEFAULT '0', `refallele` VARCHAR(1000) NULL DEFAULT NULL, `altallele` VARCHAR(1000) NULL DEFAULT NULL, `quality` DOUBLE(20,5) NULL DEFAULT NULL, `variantclass` VARCHAR(100) NULL DEFAULT NULL, `zygosity` VARCHAR(100) NULL DEFAULT NULL, `dbsnpvariant` VARCHAR(100) NULL DEFAULT NULL, PRIMARY KEY (`sampleid`, `chrom`, `position`), CONSTRAINT `varresult_ibfk_1` FOREIGN KEY (`sampleid`) REFERENCES `VarSummary` (`sampleid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- Table structure for table `VarAnnotation`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `VarAnnotation`;
CREATE TABLE `VarAnnotation` (`sampleid` VARCHAR(150) NOT NULL, `chrom` VARCHAR(100) NOT NULL DEFAULT '', `position` INT(11) NOT NULL DEFAULT '0', `consequence` VARCHAR(100) NOT NULL DEFAULT '', `source` VARCHAR(100) NULL DEFAULT NULL, `geneid` VARCHAR(1000) NOT NULL DEFAULT '', `genename` VARCHAR(1000) NULL DEFAULT NULL, `transcript` VARCHAR(250) NULL DEFAULT NULL, `feature` VARCHAR(100) NULL DEFAULT NULL, `genetype` VARCHAR(250) NULL DEFAULT NULL, `proteinposition` VARCHAR(100) NOT NULL DEFAULT '', `aachange` VARCHAR(1000) NULL DEFAULT NULL, `codonchange` VARCHAR(1000) NULL DEFAULT NULL, PRIMARY KEY (`consequence`, `geneid`, `proteinposition`, `sampleid`, `chrom`, `position`), INDEX `varannotation_indx_genename` (`genename` ASC), CONSTRAINT `varannotation_ibfk_1` FOREIGN KEY (`sampleid` , `chrom` , `position`) REFERENCES `VarResult` (`sampleid` , `chrom` , `position`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;
-- -----------------------------------------------------
-- procedure usp_vchrposition
-- -----------------------------------------------------
DROP procedure IF EXISTS `usp_vchrposition`;
CREATE PROCEDURE `usp_vchrposition`(in specie varchar(45), in chrom varchar(45), in vstart int(20), in vend int(20)) select `a`.`chrom` `chrom`, `a`.`position` `position`, `a`.`refallele` `refallele`, `a`.`altallele` `altallele`, group_concat(distinct `a`.`variantclass`) `variantclass`,`a`.`consequence` `consequence`, group_concat(distinct `a`.`genename`) `genename`, group_concat(distinct `a`.`dbsnpvariant`) `dbsnpvariant`, group_concat(distinct `a`.`sampleid`) AS `sampleid`  from `vw_vanno` `a` join `vw_sampleinfo` `b` on `a`.`sampleid` = `b`.`sampleid` where `b`.`organism` = specie and `a`.`chrom` = chrom and `a`.`position` between vstart and vend group by `a`.`chrom`, `a`.`position`, `a`.`consequence` order by `a`.`chrom`, `a`.`position`, `a`.`consequence`, `a`.`genename`, `a`.`sampleid`;
/* Create a stored procedure to get variant info after specifying chromosomal location */
/* call usp_vchrposition("Gallus gallus", "chr1", "57800", "60000"); */
-- -----------------------------------------------------
-- procedure usp_vchrom
-- -----------------------------------------------------
DROP procedure IF EXISTS `usp_vchrom`;
CREATE PROCEDURE `usp_vchrom`(in specie varchar(45), in chrom varchar(45)) select `a`.`chrom` `chrom`, `a`.`position` `position`, `a`.`refallele` `refallele`, `a`.`altallele` `altallele`, group_concat(distinct `a`.`variantclass`) `variantclass`,`a`.`consequence` `consequence`, group_concat(distinct `a`.`genename`) `genename`, group_concat(distinct `a`.`dbsnpvariant`) `dbsnpvariant`, group_concat(distinct `a`.`sampleid`) AS `sampleid`  from `vw_vanno` `a` join `vw_sampleinfo` `b` on `a`.`sampleid` = `b`.`sampleid` where `b`.`organism` = specie and `a`.`chrom` = chrom group by `a`.`chrom`, `a`.`position`, `a`.`consequence` order by `a`.`chrom`, `a`.`position`, `a`.`consequence`, `a`.`genename`, `a`.`sampleid`;
/* Create a stored procedure to get variant info after specifying chromosome */
/* call usp_vchrom("Gallus gallus", "chr1"); */
-- -----------------------------------------------------
-- procedure usp_vgene
-- -----------------------------------------------------
DROP procedure IF EXISTS `usp_vgene`;
CREATE PROCEDURE `usp_vgene`(in specie varchar(45), in gname varchar(45)) select `a`.`chrom` `chrom`, `a`.`position` `position`, `a`.`refallele` `refallele`, `a`.`altallele` `altallele`, group_concat(distinct `a`.`variantclass`) `variantclass`,`a`.`consequence` `consequence`, group_concat(distinct `a`.`genename`) `genename`, group_concat(distinct `a`.`dbsnpvariant`) `dbsnpvariant`, group_concat(distinct `a`.`sampleid`) AS `sampleid`  from `vw_vanno` `a` join `vw_sampleinfo` `b` on `a`.`sampleid` = `b`.`sampleid` where `b`.`organism` = specie and `a`.`genename` like CONCAT('%', TRIM(IFNULL(gname, '')), '%')  group by `a`.`chrom`, `a`.`position`, `a`.`consequence` order by `a`.`chrom`, `a`.`position`, `a`.`genename`, `a`.`sampleid`;
/* Create a stored procedure to get variant info after specifying genename */
/* call usp_vgene("Gallus gallus", "ND"); */
-- -----------------------------------------------------
-- procedure usp_vall
-- -----------------------------------------------------
DROP procedure IF EXISTS `usp_vall`;
CREATE PROCEDURE `usp_vall`(in specie varchar(45)) select `a`.`chrom` `chrom`, `a`.`position` `position`, `a`.`refallele` `refallele`, `a`.`altallele` `altallele`, group_concat(distinct `a`.`variantclass`) `variantclass`,`a`.`consequence` `consequence`, group_concat(distinct `a`.`genename`) `genename`, group_concat(distinct `a`.`dbsnpvariant`) `dbsnpvariant`, group_concat(distinct `a`.`sampleid`) AS `sampleid`  from `vw_vanno` `a` join `vw_sampleinfo` `b` on `a`.`sampleid` = `b`.`sampleid` where `b`.`organism` = specie group by `a`.`chrom`, `a`.`position`, `a`.`consequence` order by `a`.`chrom`, `a`.`position`, `a`.`consequence`, `a`.`genename`, `a`.`sampleid`;
/* Create a stored procedure to get variant info after only species */
/* call usp_vall("Gallus gallus"); */
-- -----------------------------------------------------
-- View `vw_sampleinfo`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_sampleinfo`;
DROP TABLE IF EXISTS `vw_sampleinfo`;
CREATE TABLE `vw_sampleinfo` (`sampleid` INT, `organism` INT, `tissue` INT, `totalreads` INT, `mappedreads` INT, `alignmentrate` INT,`genes` INT, `totalvariants` INT, `totalsnps` INT, `totalindels` INT);
DROP VIEW IF EXISTS `vw_sampleinfo` ;
DROP TABLE IF EXISTS `vw_sampleinfo`;
CREATE VIEW `vw_sampleinfo` AS select `a`.`sampleid` AS `sampleid`, `e`.`organism` AS `organism`,`a`.`tissue` AS `tissue`, `b`.`totalreads` AS `totalreads`, `b`.`mappedreads` AS `mappedreads`, `b`.`alignmentrate` AS `alignmentrate`,`c`.`genes` AS `genes`,`d`.`totalvariants` AS `totalvariants`,`d`.`totalsnps` AS `totalsnps`,`d`.`totalindels` AS `totalindels` from ((((`Sample` `a` join `Animal` `e` on ((`a`.`derivedfrom` = `e`.`animalid`))) join `MapStats` `b` on((`a`.`sampleid` = `b`.`sampleid`))) left outer join `GeneStats` `c` on ((`b`.`sampleid` = `c`.`sampleid`))) left outer join `VarSummary` `d` on ((`a`.`sampleid` = `d`.`sampleid`)));
-- -----------------------------------------------------
-- View `vw_nosql`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_nosql`;
DROP TABLE IF EXISTS `vw_nosql`;
CREATE TABLE `vw_nosql` (`variantclass` INT,`zygosity` INT,`dbsnpvariant` INT,`source` INT,`consequence` INT,`geneid` INT,`genename` INT,`transcript` INT,`feature` INT,`genetype` INT,`refallele` INT,`altallele` INT,`tissue` INT,`chrom` INT,`aachange` INT,`codonchange` INT,`organism` INT,`sampleid` INT,`quality` INT,`position` INT,`proteinposition` INT);
DROP VIEW IF EXISTS `vw_nosql` ;
DROP TABLE IF EXISTS `vw_nosql`;
CREATE VIEW `vw_nosql` AS select `a`.`variantclass` AS `variantclass`,`a`.`zygosity` AS `zygosity`,`a`.`dbsnpvariant` AS `dbsnpvariant`,`b`.`source` AS `source`,`b`.`consequence` AS `consequence`,`b`.`geneid` AS `geneid`,`b`.`genename` AS `genename`,`b`.`transcript` AS `transcript`,`b`.`feature` AS `feature`,`b`.`genetype` AS `genetype`,`a`.`refallele` AS `refallele`,`a`.`altallele` AS `altallele`,`c`.`tissue` AS `tissue`,`a`.`chrom` AS `chrom`,`b`.`aachange` AS `aachange`,`b`.`codonchange` AS `codonchange`,`d`.`organism` AS `organism`,`a`.`sampleid` AS `sampleid`,`a`.`quality` AS `quality`,`a`.`position` AS `position`,`b`.`proteinposition` AS `proteinposition` from (((`VarResult` `a` join `VarAnnotation` `b` on (((`a`.`sampleid` = `b`.`sampleid`) and (`a`.`chrom` = `b`.`chrom`) and (`a`.`position` = `b`.`position`)))) join Sample `c` on ((`a`.`sampleid` = `c`.`sampleid`))) join Animal `d` on ((`c`.`derivedfrom` = `d`.`animalid`)));
-- -----------------------------------------------------
-- View `vw_metadata`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_metadata`;
DROP TABLE IF EXISTS `vw_metadata`;
CREATE TABLE `vw_metadata` (`sampleid` INT,`animalid` INT,`organism` INT,`tissue` INT,`personid` INT,`organizationname` INT,`animaldescription` INT,`sampledescription` INT, `date` INT);
DROP VIEW IF EXISTS `vw_metadata` ;
DROP TABLE IF EXISTS `vw_metadata`;
CREATE VIEW `vw_metadata` AS select `a`.`sampleid` as `sampleid`, `a`.`derivedfrom` as `animalid`, `b`.`organism` as `organism`, `a`.`tissue` as `tissue`, `c`.`personid` as `personid`, `d`.`organizationname` as `organizationname`, `b`.`description` as `animaldescription`, `a`.description as `sampledescription`, `a`.`date` as `date` from (((`Sample` `a` join `Animal` `b` on ((`a`.`derivedfrom` = `b`.`animalid`))) left outer join `SamplePerson` `c` on ((`a`.`sampleid` = `c`.`sampleid`))) left outer join `SampleOrganization` `d` on ((`a`.`sampleid` = `d`.`sampleid`)));
-- -----------------------------------------------------
-- View `vw_vanno`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_vanno`;
DROP TABLE IF EXISTS `vw_vanno`;
CREATE TABLE `vw_vanno` (`chrom` INT, `position` INT, `refallele` INT, `altallele` INT, `variantclass` INT, `consequence` INT, `genename` INT, `dbsnpvariant` INT, `sampleid` INT);
DROP VIEW IF EXISTS `vw_vanno` ;
DROP TABLE IF EXISTS `vw_vanno`;
CREATE VIEW `vw_vanno` AS select `a`.sampleid, `a`.`chrom` AS `chrom`,`a`.`position` AS `position`,`a`.`refallele` AS `refallele`,`a`.`altallele` AS `altallele`,`a`.`variantclass` AS `variantclass`,ifnull(`b`.`consequence`,'-') AS `consequence`,`b`.`genename` AS `genename`,`a`.`dbsnpvariant` AS `dbsnpvariant` from (`VarResult` `a` left outer join `VarAnnotation` `b` on(((`a`.`sampleid` = `b`.`sampleid`) and (`a`.`chrom` = `b`.`chrom`) and (`a`.`position` = `b`.`position`)))) group by `a`.`sampleid`, `a`.`chrom`,`a`.`position`,`b`.`consequence`,`b`.`genename`;
-- -----------------------------------------------------
-- View `vw_vvcf`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_vvcf`;
DROP TABLE IF EXISTS `vw_vvcf`;
CREATE TABLE `vw_vvcf` (`sampleid` INT, `chrom` INT, `position` INT, `refallele` INT, `altallele` INT, `quality` INT, `consequence` INT, `genename` INT, `geneid` INT, `feature` INT, `transcript` INT, `genetype` INT, `proteinposition` INT, `aachange` INT, `codonchange` INT, `dbnpvariant` INT, `variantclass` INT, `zygosity` INT, `tissue` INT, `organism` INT);
DROP VIEW IF EXISTS `vw_vvcf` ;
DROP TABLE IF EXISTS `vw_vvcf`;
CREATE VIEW `vw_vvcf` AS select `a`.`sampleid` as `sampleid`, `a`.`chrom` AS `chrom`,`a`.`position` AS `position`,`a`.`refallele` AS `refallele`,`a`.`altallele` AS `altallele`,`a`.`quality` as `quality`, `b`.`consequence` as `consequence`, `b`.`genename` AS `genename`,`b`.`geneid` AS `geneid`,`b`.`feature` AS `feature`,`b`.`transcript` AS `transcript`,`b`.`genetype` AS `genetype`,`b`.`proteinposition` AS `proteinposition`,`b`.`aachange` AS `aachange`,`b`.`codonchange` AS `codonchange`,`a`.`dbsnpvariant` AS `dbsnpvariant`,`a`.`variantclass` AS `variantclass`,`a`.`zygosity` AS `zygosity`,`c`.`tissue` AS `tissue`, `c`.`organism` AS `organism` from ((`VarResult` `a` left outer join `VarAnnotation` `b` on (((`a`.`sampleid` = `b`.`sampleid`) and (`a`.`chrom` = `b`.`chrom`) and (`a`.`position` = `b`.`position`)))) join `vw_sampleinfo` `c` on ((`a`.`sampleid` = `c`.`sampleid`))) order by `a`.`sampleid`, `a`.`chrom`,`a`.`position`, `b`.`consequence`;
-- -----------------------------------------------------
-- View `vw_seqstats`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `vw_seqstats`;
DROP TABLE IF EXISTS `vw_seqstats`;
CREATE TABLE `vw_seqstats` ( `sampleid` INT, `totalreads` INT, `alignmentrate` INT, `genes` INT, `totalvariants` INT, `mappingtool` INT, `annotationfile` INT, `mapdate` INT, `diffexpresstool` INT, `countstool` INT, `genedate` INT, `varianttool` INT, `variantannotationtool` INT, `variantdate` INT);
DROP VIEW IF EXISTS `vw_seqstats`;
DROP TABLE IF EXISTS `vw_seqstats`;
CREATE VIEW `vw_seqstats` AS select `a`.`sampleid` AS `sampleid`,`a`.`totalreads` AS `totalreads`,`a`.`alignmentrate` AS `alignmentrate`,`a`.`genes` AS `genes`,`a`.`totalvariants` AS `totalvariants`,`b`.`mappingtool` AS `mappingtool`,`b`.`annfile` AS `annotationfile`,`c`.`date` AS `mapdate`,`d`.`diffexpresstool` AS `diffexpresstool`,`d`.`countstool` AS `countstool`,`d`.`date` AS `genedate`,`e`.`varianttool` AS `varianttool`,`e`.`annversion` AS `variantannotationtool`,`e`.`date` AS `variantdate` from ((((`vw_sampleinfo` `a` join `Metadata` `b` on((`a`.`sampleid` = `b`.`sampleid`))) join `MapStats` `c` on((`a`.`sampleid` = `c`.`sampleid`))) left outer join `GeneStats` `d` on((`a`.`sampleid` = `d`.`sampleid`))) left outer join `VarSummary` `e` on((`a`.`sampleid` = `e`.`sampleid`))) order by `a`.`sampleid`;
-- -----------------------------------------------------
