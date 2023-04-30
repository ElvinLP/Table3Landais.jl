```@meta
CurrentModule = Table3Landais
```

# Table3Landais

Documentation for [Table3Landais](https://github.com/ElvinLP/Table3Landais.jl).

The package [Table3Landais](https://github.com/ElvinLP/Table3Landais.jl) was designed to replicate Table 3 from Camille Landais' paper ["Assessing the Welfare Effects of Unemployment Benefits Using the Regression Kink Design"](https://www.aeaweb.org/articles?id=10.1257/pol.20130248).

# Before using this package

Please make sure you have downloaded the necessary files from the online [Replication Package](https://www.openicpsr.org/openicpsr/project/114581/version/V1/view) on the AER website.
Once downloaded, all the files are stored in a repository called "Prog_AEJ_RKD". 
The raw files needed to replicate Table 3 of the paper are:
- Prog_AEJ_RKD\Data\rawdata\cwbh_LA.dta
- Prog_AEJ_RKD\Data\cpi2.dta

# Functions

The package is made of 2 functions:

1. cleandata()

Cleans the raw "cwbh_LA.dta" file and deflate some variables using "cpi2.dta" to produce "base_2_LA.dta", the 282,968×178 baseline sample used for the regression discontinuity analysis. This file is stored in the "Prog_AEJ_RKD\Data" repository. The compilation takes around 2 minutes.

2. Table3()

Iterates over the 3 periods, 7 outcome variables and 3 polynomial specifications to output a LaTex code that is to be pasted in a LaTex compiler to produce Table 3 of the paper. It also produces a temporary CSV file, "base_reg_LA.csv", which serves as the base file for each specification, and stores the results of all the 63 different specifications in a CSV file called "Table_3.csv." which is stored in the "Prog_AEJ_RKD\Output" repository. In Table 3 of the paper, only the polynomial specifications with the lowest Akaike Information Criterion (AIC) are presented. The compilation takes around 12 minutes and the period, outcome variable, and polynomial specification are displayed at each iteration.

# Input

Both of these functions take as an argument a string describing the path to the "Prog_AEJ_RKD" repository on your computer. Remember that you need to write this path between quotations marks and with "/" instead of "\".
For example:
"D:/SciencesPo/Cours/M2Economics/Springsemester/comput_econ/replication_landais/Prog_AEJ_RKD"

# Important Information:

Output:
The code replicates exactly the results of the paper up to two exceptions:
1. We think the column names "duratuiclaimed" and "duratuipaid" are inverted in the paper. We systematically obtain the results of the other column while running the regression for the other variable and the other way around. The Stata code provided in the replication package outputs the same results as our package.
2. The coefficient we obtain for age in the first period is -3.277 and not 0.277 as featured in the paper. We believe it is a typo in the paper since the number of observations, standard errors, optimal polynomial value and p-value we obtain are the same as reported in the paper. The Stata code provided in the replication package gives a coefficient of 0.277 too.

```@index
```

```@autodocs
Modules = [Table3Landais]
```
