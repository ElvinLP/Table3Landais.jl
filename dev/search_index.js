var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = Table3Landais","category":"page"},{"location":"#Table3Landais","page":"Home","title":"Table3Landais","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for Table3Landais.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The package Table3Landais was designed to replicate Table 3 from Camille Landais' paper \"Assessing the Welfare Effects of Unemployment Benefits Using the Regression Kink Design\".","category":"page"},{"location":"#Before-using-this-package","page":"Home","title":"Before using this package","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Please make sure you have downloaded the necessary files from the online Replication Package on the AER website. Once downloaded, all the files are stored in a repository called \"ProgAEJRKD\".  The raw files needed to replicate Table 3 of the paper are:","category":"page"},{"location":"","page":"Home","title":"Home","text":"ProgAEJRKD\\Data\\rawdata\\cwbh_LA.dta\nProgAEJRKD\\Data\\cpi2.dta","category":"page"},{"location":"#Functions","page":"Home","title":"Functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The package is made of 2 functions, cleandata() and Table3(). They are to be run in that order.","category":"page"},{"location":"","page":"Home","title":"Home","text":"cleandata()","category":"page"},{"location":"","page":"Home","title":"Home","text":"Cleans the raw \"cwbhLA.dta\" file and expresses variables \"earnings\" and \"wba\" in real dollars using \"cpi2.dta\". It produces the file \"base2LA.dta\", the 282,968×178 baseline sample used for the regression kink design. This file is stored in the \"ProgAEJ_RKD\\Data\" repository. The compilation takes around 2 minutes.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Table3()","category":"page"},{"location":"","page":"Home","title":"Home","text":"Iterates over the 3 periods, 7 outcome variables and 3 polynomial specifications to output a LaTex code that is to be pasted in a LaTex compiler to produce Table 3 of the paper. It also produces a temporary CSV file, \"baseregLA.csv\", which serves as the base file for each specification, and stores the results of all the 63 different specifications in a CSV file called \"Table3.csv.\" which is stored in the \"ProgAEJ_RKD\\Output\" repository. In Table 3 of the paper, only the polynomial specifications with the lowest Akaike Information Criterion (AIC) are presented. The compilation takes around 12 minutes and the period, outcome variable, and polynomial specification are displayed at each iteration.","category":"page"},{"location":"#Input","page":"Home","title":"Input","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Both of these functions take as an argument a string describing the path to the \"ProgAEJRKD\" repository on your computer. Remember that you need to write this path between quotations marks and with \"/\" instead of \"\\\". For example: \"D:/SciencesPo/Cours/M2Economics/Springsemester/computecon/replicationlandais/ProgAEJRKD\"","category":"page"},{"location":"#Important-Information:","page":"Home","title":"Important Information:","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Output: The code replicates exactly the results of the paper up to two exceptions:","category":"page"},{"location":"","page":"Home","title":"Home","text":"We think the column names \"duratuiclaimed\" and \"duratuipaid\" are inverted in the paper. When running the analysis for one variable, we systematically obtain the results of the other column and the other way around. The Stata code provided in the replication package outputs the same results as our package.\nThe coefficient we obtain for age in the first period is -3.277 and not 0.277 as featured in the paper. We believe it is a typo in the paper since the number of observations, standard errors, optimal polynomial value and p-value we obtain are the same as reported in the paper. The Stata code provided in the replication package gives a coefficient of 0.277 too.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [Table3Landais]","category":"page"}]
}