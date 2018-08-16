# TransAtlasDB main package

## TransAtlasDB Example Files

TransAtlasDB is a sophisticated database system for the different types of results generated from transcriptome profiling and variant calling using high-throughput RNASeq data.

This folder provides an example of the different types of information required by TransAtlasDB and how the data types should be stored for successful storage in TransAtlasDB.
The different types of information can be broadly grouped into four categories which are listed below, with their applicable software.

1. Sample Information, or commonly known as the samples metadata.
  * FAANG
  * Tab-delimited file

2. Alignment (Mapping) Information.
  * TopHat2
  * HISAT2

3. Expression Information.
  * Cufflinks
  * StringTie

4. Variant Information.
  * GATK 
  * SAMtools (BCFtools)

All required input files should be stored in a single folder, which should be named the _Sample Name_ of the corresponding sample in the samples metadata, as shown.

### Folder details:
* _**metadata**_ : contains the samples information using either the tab-delimited file or the FAANG biosamples spreadsheet.

* _**sample_sxt**_ : contains the mapping, expression and variant information generated from different tools to showcase the versatility of TransAtlasDB.

 | **Sample files**         | Mapping             | Expression   (ReadCounts)      | Variants  (Annotation )    |
 |:-------------------------|:--------------------|:-------------------------------|:---------------------------|
 | **GGA_UD_1004**          | TopHat2             | Cufflinks    (htseq-count)     | GATK      (ANNOVAR)        |
 | **GGA_UD_1014**          | HISAT2              | StringTie    (featureCounts)   | Samtools  (VEP)            | 
 | **SRR1334787**           |                     | Salmon                         |                            |
 | **SRR1698098**           | HISAT2              |                                | Samtools                   | 
 | **SRR1772412**           | TopHat2             |              (featureCounts)   |                            |
 | **SRR3089603**           | HISAT2              | StringTie                      |                            |
 | **SRR3089604**           | Kallisto            | Kallisto                       |                            |
 | **SRR527164**            | HISAT2              |              (htseq-count)     |                            |
 | **SRR5409491**           | STAR                |              (STAR quantMode)  | GATK      (VEP)            |


**P.S.**: The data files provided are simulated for tutorial purposes.

Please click the menu items to navigate through this repository. If you have questions, comments and bug reports, please email me directly. Thank you very much for your help and support!

---
