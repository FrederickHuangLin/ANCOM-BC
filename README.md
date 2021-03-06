# User Manual for ANCOM-BC Function
[![DOI](https://zenodo.org/badge/198737095.svg)](https://zenodo.org/badge/latestdoi/198737095)

This is the repository archiving data and scripts for reproducing results presented in the Nat. Comm. paper [ANCOM-BC](https://www.nature.com/articles/s41467-020-17041-7). 

**For the corresponding R package, refer to [ANCOMBC](https://github.com/FrederickHuangLin/ANCOMBC) repository.**

The current code implements ANCOM-BC in cross-sectional datasets for comparing the change of absolute abundance for each taxon among different experimental groups. 

## R-package dependencies
The following libraries need to be included for the R code to run:

```r
library(dplyr)
library(nloptr)
```

## Instructions for use

### Data preprocess

#### Usage

* ```feature_table_pre_process(feature.table, meta.data, sample.var, group.var, zero.cut, lib.cut, neg.lb)```

#### Arguments

*	```feature.table```: Data frame or matrix representing observed OTU table with OTUs (or taxa) in rows and samples in columns.
*	```meta.data```: Data frame or matrix of all variables and covariates of interest.
*	```sample.var```: Character. The name of column storing sample IDs.
*	```group.var```: Character. The name of the main variable of interest. ANCOM-BC v1.0 only supports discrete ```group.var``` and aims to compare the change of absolute abundance across different levels of ```group.var```.
*	```zero.cut```: Numerical fraction between 0 and 1. Taxa with proportion of zeroes greater than ```zero.cut``` are not included in the analysis.
* ```lib.cut```: Numeric. Samples with library size less than ```lib.cut``` are not included in the analysis.
*	```neg.lb```: Logical. TRUE indicates a taxon would be classified as a structural zero in the corresponding experimental group using its asymptotic lower bound.

#### Value

* ```feature.table```: A data frame of pre-processed OTU table.
*	```library.size```: A numeric vector of library sizes after pre-processing.
*	```group.name```: A character vector of levels of ```group.var```.
*	```group.ind```: A numeric vector. Each sample is assigned to a number indicating its group label for better internal process.
*	```structure.zeros```: A matrix consists of 0 and 1s with 1 indicating the taxon is identified as a structural zero in the corresponding group.

### ANCOM-BC main function

#### Usage:

*	```ANCOM_BC(feature.table, grp.name, grp.ind, struc.zero, adj.method, tol.EM, max.iterNum, perNum, alpha)```

#### Arguments:

*	```feature.table```: Data frame or matrix representing the pre-processed OTU table with OTUs (or taxa) in rows and samples in columns. 
*	```grp.name```: A character vector indicating the levels of group. 
*	```grp.ind```: A numeric vector indicating group assignment for each sample. 1 corresponds to the 1st level of ```grp.name```, 2 corresponds to the 2nd level of ```grp.name```, etc.
*	```struc.zero```: A matrix consists of 0 and 1s with 1 indicating the taxon is identified as a structural zero in the corresponding group.
*	```adj.method```: Character. Returns p-values adjusted using the specified method, including ```"holm", "hochberg", "hommel", "bonferroni", "BH", "BY", "fdr", "none"```.
*	```tol.EM```: Numeric. The iteration convergence tolerance for E-M algorithm.
*	```max.iterNum```: Numeric. The maximum number of iterations for E-M algorithm.
* ```perNum```: Numeric. The maximum number of permutations. This argument is active only if there exist more than 2 groups.
*	```alpha```: Numeric. Level of significance.

#### Value:
*	```feature.table```: Data frame or matrix. Return the input ```feature.table```.
*	```res```: Data frame. The primary result of ANCOM-BC consisting of: 
    * ```mean.difference```: Numeric. The estimated mean difference of absolute abundance between groups in log scale (natural log);
    * ```se```: Numeric. The standard error of ```mean.difference```;
    * ```W```: Numeric. ```mean.difference/se```, which is the test statistic of ANCOM-BC.
    * ```p.val```: Numeric. P-value obtained from two-sided Z-test using the test statistic ```W```.
    * ```q.val```. Numeric. Q-value obtained by applying ```adj.method``` to ```p-val```.
    * ```diff.abn```. Logical. TRUE if the taxon has ```q.val``` less than ```alpha```.
*	```d```: A numeric vector. Estimated sampling fractions in log scale (natural log).
*	```mu```: A numeric vector. Estimated log (natural log) mean absolute abundance for each group.
*	```bias.em```: Numeric. Estimated mean difference of log (natural log) sampling fractions between groups through E-M algorithm.
*	```bias.wls```: Numeric. Estimated mean difference of log (natural log) sampling fractions between groups through weighted least squares.

## Flowchart of ANCOM-BC

<img src="/demos/flowchart.jpg" width="400" height="700">

## Examples

```r
# Load example data
data(dietswap)
pseq = dietswap
n_taxa = ntaxa(pseq)
n_samp = nsamples(pseq)
# Metadata
meta_data = meta(pseq)
# Taxonomy table
taxonomy = tax_table(pseq)
# Absolute abundances
otu_absolute = abundances(pseq)
```

### Two-group comparison

```r
# Pre-processing
feature.table = otu_absolute; sample.var = "sample"; group.var = "nationality"; 
zero.cut = 0.90; lib.cut = 1000; neg.lb = TRUE
pre.process = feature_table_pre_process(feature.table, meta_data, sample.var, 
                                        group.var, zero.cut, lib.cut, neg.lb)
feature.table = pre.process$feature.table
group.name = pre.process$group.name
group.ind = pre.process$group.ind
struc.zero = pre.process$structure.zeros

# Paras for ANCOM-BC
grp.name = group.name; grp.ind = group.ind; adj.method = "bonferroni"
tol.EM = 1e-5; max.iterNum = 100; perNum = 1000; alpha = 0.05

out = ANCOM_BC(feature.table, grp.name, grp.ind, struc.zero,
               adj.method, tol.EM, max.iterNum, perNum, alpha)
res = cbind(taxon = rownames(out$feature.table), out$res)
write_csv(res, "demo_two_group.csv")
```

Expected run time: 6s (R version 3.5.1 (2018-07-02); Platform: x86_64-apple-darwin15.6.0 (64-bit); Running under: macOS  10.15.1.)

### Multi-group comparison

```r
# Pre-processing
feature.table = otu_absolute; sample.var = "sample"; group.var = "bmi_group"; 
zero.cut = 0.90; lib.cut = 1000; neg.lb = TRUE
pre.process = feature_table_pre_process(feature.table, meta_data, sample.var, 
                                        group.var, zero.cut, lib.cut, neg.lb)
feature.table = pre.process$feature.table
group.name = pre.process$group.name
group.ind = pre.process$group.ind
struc.zero = pre.process$structure.zeros

# Paras for ANCOM-BC
grp.name = group.name; grp.ind = group.ind; adj.method = "bonferroni"
tol.EM = 1e-5; max.iterNum = 100; perNum = 1000; alpha = 0.05

out = ANCOM_BC(feature.table, grp.name, grp.ind, struc.zero,
               adj.method, tol.EM, max.iterNum, perNum, alpha)
res = cbind(taxon = rownames(out$feature.table), out$res)
write_csv(res, "demo_multi_group.csv")
```

Expected run time: 19s (R version 3.5.1 (2018-07-02); Platform: x86_64-apple-darwin15.6.0 (64-bit); Running under: macOS  10.15.1.)
