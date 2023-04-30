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



The package is made of 2 functions:

1. Table3Landais.cleandata() take as an argument a string of your path to the folder where you have stored the

Important Information:

Code:
There are 7 variables in the table. 3 periods and 3 possible polynomial specifications.
In total 63 specifications are run. 
Then Select the lowest Aikake information (AIC).

Output:
The code produces a latex code that is to be pasted in a latex compiler to produce Table 3 of the paper
The code replicate exactly the results of the paper up to exceptions: 
1. We think the columns duratuiclaimed and duratuipaid are inverted in the paper. We systematically obtain the results of the other column while running the analysis regression on the other variable and the other way around.
2. The coefficient we obtain for age in the first period is -3.227 and not 0.227 as in the paper. We believ

```@index
```

```@autodocs
Modules = [Table3Landais]
```
