module Table3Landais

using Pkg
using DataFrames
using CSV
using Dates
using Statistics
using CategoricalArrays
using GLM
using StatsBase
using MixedModels
using CategoricalArrays
using CovarianceMatrices
using Vcov
using FixedEffectModels
using RobustModels
using Distributions
using ReadStatTables
using Latexify
using ReadStatTables

function cleandata(pathfolder::String)
##############################################
#### Clean the raw database for LOUISIANA ####
##############################################
#Load necessary packages
# This programs automatically cleans the original CWBH file foir Louisiana to be readily available for the RKD
df = readstat("$pathfolder/Data/rawdata/cwbh_LA.dta")
df = DataFrame(df)

# Key point: all claims are identified by id # of the unemployed + date benefit year begins
# we keep only claims with enough wages to be eligible for benefits
subset!(df, :r2v18 => x -> x .== 1, skipmissing=true)
rename!(df,:r2v18 => :wage_qualif)

# We we keep only claims in regular state UI programs 
# (not other special programs for specific occupations like UCFE or UCX)
subset!(df, :r2v20 => x -> x .== 1, skipmissing=true)
rename!(df,:r2v20 => :UI_prog1)
subset!(df, :r2v21 => x -> x .== 0, skipmissing=true)
rename!(df,:r2v21 => :UI_prog2)

# Keep only claims with record type==4 => each week claimed by the
# claimant associated with the given benefit year claim
subset!(df, :rectype => x -> x .== 4, skipmissing=true)

# Keep only new claims (and not transitional claims)
# Caution: for a lot of States, transitional claims are not properly identified (cf documentation CWBH)
subset!(df, :r3v7 => x -> x .== 1, skipmissing=true)
rename!(df,:r3v7 => :type_claim)

# We keep only claims that are not subject to denials of compensation, and that are not put in suspense
subset!(df, :r4v9 => x -> x .== 0, skipmissing=true)
rename!(df,:r4v9 => :claim_denied)

# We keep only weeks for which the claim is for total unemployment with no UI reduction
rename!(df,:r4v6 => :type_week_claim)
rename!(df,:r3v27 => :recall_exp)

# We keep only people who did not have any disqualification for UI because of separation issues
# with previous employers (misconduct, etc...) (the info is missing for Louisiana)
rename!(df,:r3v17 => :disqualif_sep)
transform!(df, [:disqualif_sep] => ((x1) -> 0) => :disqualif_sep)
subset!(df, :disqualif_sep => x -> x .== 0, skipmissing=true)

# key variable= week certified ending date: since each observation is a week claimed,
# this variable tells you the date of the given week claimed.
rename!(df,:r4v16 => :date_week_certif)

# define duration as consecutive weeks in date_week_certif:
# define lag (in weeks) between two certified ending weeks
rename!(df,:r2v31 => :begin_benf_yr)
sort!(df, [:id, :begin_benf_yr, :date_week_certif])

transform!(df, [:date_week_certif] => ((x1) -> string.(x1)) => :date_week_certif)
transform!(df, [:date_week_certif] => ((x1) -> SubString.(x1,1,2)) => :yr1)
transform!(df, [:date_week_certif] => ((x1) -> SubString.(x1,3,4)) => :month1)
transform!(df, [:date_week_certif] => ((x1) -> SubString.(x1,5,6)) => :date1)

for var ∈ [:yr1, :month1, :date1]
transform!(df, var => ((x1) -> parse.(Float64, x1)) => var)
end
transform!(df, [:yr1] => ((x1) -> x1 .+ 1900) => :yr1)
transform!(df, [:yr1, :month1, :date1] => ((x1,x2,x3) -> Date.(x1,x2,x3)) => :date_week_certif_2)

insertcols!(df, :lag => missings(Int64, length(df.date_week_certif_2)))
transform!(df, [:date_week_certif_2] => ((x1) -> (x1 .- lag(x1))) => :lag1)
df[2:end,:] = transform!(df[2:end,:], [:lag1] => ((x1) -> Dates.value.(x1)) => :lag)
df = df[:,Not(:lag1)]

df[!,:interrup] = ifelse.(coalesce.(df.lag .> 21, false) .& coalesce.(df.id .== lag(df.id), false) .& coalesce.(df.begin_benf_yr .== lag(df.begin_benf_yr), false), 1, missing)
df[!,:lag] = ifelse.(coalesce.(df.id .!= lag(df.id), false) .| coalesce.(df.begin_benf_yr .!= lag(df.begin_benf_yr), false), missing, df.lag)
df[!,:interrup] = ifelse.(ismissing.(df.interrup),0,df.interrup)

df2 = transform(df, [:date_week_certif_2] => ((x1) -> x1) => :date_week_certif_2bis)
df2 = combine(groupby(df2, [:id, :begin_benf_yr]; sort = true), [:interrup, :date_week_certif_2, :date_week_certif_2bis] .=> (mean, maximum, minimum); renamecols=false)

rename!(df2, :interrup => :interrupted_claim)
rename!(df2, :date_week_certif_2 => :end_claim)
rename!(df2, :date_week_certif_2bis => :start_claim)

df = innerjoin(df2, df, on = [:id, :begin_benf_yr])

df[!,:interrupted_claim] = ifelse.(coalesce.(df.interrupted_claim .> 0, false), 1, df.interrupted_claim)

df = transform(df, [:start_claim,:end_claim] => ((x1,x2) -> Dates.value.(x2 .- x1)) => :duration)

# We also use the variables durat_uiclaimed & durat_uipaid from the CWBH which tells us total number of weeks paid for
# UI in a given benefit year (so all weeks for a given claim excluding weeks of interruption)
rename!(df, :r2v51 => :durat_uiclaimed)
rename!(df, :r2v52 => :durat_uipaid)

# Base period earnings and highest quarter wage
rename!(df, :r2v23 => :bpw)
rename!(df, :r2v24 => :hqw)

# Weekly benefit amount paid (gross)
rename!(df, :r2v28 => :wba_gross)

# Weekly benefit amount paid (with dependent's allowances)
rename!(df, :r2v27 => :wba_augmented)

# Variable indicating the program tier 
# (normal/ext benef/FSC) for the certified week
rename!(df, :r4v10 => :prog_tier_number)

# Variable indicating whether tier 2 or 4 programs had their trigger
# on (EB/FSC) for the certified week
rename!(df, :r4v21 => :trigger)

# formatting in date format the beginning of the benefit year
df = transform(df, [:begin_benf_yr] => ((x1) -> string.(x1)) => :begin_benf_yr)
transform!(df, [:begin_benf_yr] => ((x1) -> SubString.(x1,1,2)) => :yr_bbf)
transform!(df, [:begin_benf_yr] => ((x1) -> SubString.(x1,3,4)) => :month_bbf)
transform!(df, [:begin_benf_yr] => ((x1) -> SubString.(x1,5,6)) => :date_bbf)

for var ∈ [:yr_bbf, :month_bbf, :date_bbf]
    transform!(df, var => ((x1) -> parse.(Float64, x1)) => var)
end
transform!(df, [:yr_bbf] => ((x1) -> x1 .+ 1900) => :yr_bbf)
transform!(df, [:yr_bbf, :month_bbf, :date_bbf] => ((x1,x2,x3) -> Date.(x1,x2,x3)) => :begin_benf_yr_2)

# Potential duration:
rename!(df, :r2v30 => :potduration) #potential duration for tier 1

# /* !!!!!!!!!
#We now get proper durations taking into account all EB and FSC tiers based on federal and state
# regulations and info (see paper's appendix for details)
#!!!!!!!!!!!!*/
#/* all info on potential duration come from Woodford & Vroman: th duration of benefits 
#(in Unemployment Insurance in the US) cf. table 6.7 p.252 */
transform!(df, [:potduration] => ((x1) -> x1) => :potduration_alltiers)

# Louisiana
    # Regular EB program
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1975,2,23), false) .& coalesce.(df.date_week_certif_2 .<= Date(1977,7,2), false), min.(39.0, min.(13.0, 0.5*df.potduration) + df.potduration), df.potduration_alltiers)
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1977,8,28), false) .& coalesce.(df.date_week_certif_2 .<= Date(1978,1,28), false), min.(39.0, min.(13.0, 0.5*df.potduration) + df.potduration), df.potduration_alltiers)
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1980,7,20), false) .& coalesce.(df.date_week_certif_2 .<= Date(1981,1,24), false), min.(39.0, min.(13.0, 0.5*df.potduration) + df.potduration), df.potduration_alltiers)
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1981,9,12), false) .& coalesce.(df.date_week_certif_2 .<= Date(1982,10,23), false), min.(39.0, min.(13.0, 0.5*df.potduration) + df.potduration), df.potduration_alltiers)
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,1,23), false), min.(39.0, min.(13.0, 0.5*df.potduration) + df.potduration), df.potduration_alltiers)

    # Federal Extensions: FSC Program
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1982,9,12), false) .& coalesce.(df.date_week_certif_2 .<= Date(1983,1,8), false), df.potduration_alltiers .+ min.(10.0, 0.5*df.potduration), df.potduration_alltiers) # FSC-I
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,1,9), false) .& coalesce.(df.date_week_certif_2 .<= Date(1983,3,20), false), df.potduration_alltiers .+ min.(14.0, 0.65*df.potduration), df.potduration_alltiers) # FSC-II
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,3,20), false) .& coalesce.(df.date_week_certif_2 .<= Date(1983,3,31), false), df.potduration_alltiers .+ min.(16.0, 0.65*df.potduration), df.potduration_alltiers) # FSC-II
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,4,1), false) .& coalesce.(df.date_week_certif_2 .<= Date(1983,6,19), false), df.potduration_alltiers .+ min.(14.0, 0.55*df.potduration), df.potduration_alltiers) # FSC-III
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,6,19), false) .& coalesce.(df.date_week_certif_2 .<= Date(1983,10,19), false), df.potduration_alltiers .+ min.(12.0, 0.55*df.potduration), df.potduration_alltiers) # FSC-III
df[!,:potduration_alltiers] = ifelse.(coalesce.(df.date_week_certif_2 .> Date(1983,10,19), false), df.potduration_alltiers .+ min.(12.0, 0.55*df.potduration), df.potduration_alltiers) # FSC-III

# we only keep spells for which the time between claim and first week
# certified is inferior to 2 weeks
# keep if start_claim-begin_benf_yr_2<=14 & start_claim-begin_benf_yr_2>=0

# we only keep spells for which the total time UI was paid does not
# exceed total potential duration by more than 5 weeks
# keep if durat_uipaid-potduration_alltiers<=5

# Other demographics:
transform!(df, [:yr, :r2v11] => ((x1,x2) -> x1 .- x2) => :age)
df[!,:age] = ifelse.(coalesce.(df.r2v11 .== 99), missing, df.age)

insertcols!(df, :male => ifelse.(coalesce.(df.r2v10 .== 1, false), 1, 0))
df[!,:male] = ifelse.(coalesce.(df.r2v10 .== 9, false) .| coalesce.(df.r2v10 .== 0, false), missing, df.male)

insertcols!(df, :black => ifelse.(coalesce.(df.r2v13 .== 2, false), 1, 0))
df[!,:black] = ifelse.(coalesce.(df.r2v13 .== 6, false), missing, df.black)

rename!(df, :r2v13 => :ethnic)

insertcols!(df, :college => ifelse.(coalesce.(df.r2v12 .>= 13, false) .& coalesce.(df.r2v12 .!= 99, false), 1, 0))
df[!,:college] = ifelse.(coalesce.(df.r2v12 .== 99, false), missing, df.college)

rename!(df, :r2v12 => :schooling)
transform!(df, [:schooling] => ((x1) -> x1) => :yr_education)
df[!,:yr_education] = ifelse.(coalesce.(df.schooling .== 99, false), missing, df.yr_education)

insertcols!(df, :dependents => ifelse.(coalesce.(df.r3v32 .!= 9, false), df.r3v32, missing))

transform!(df, [:r3v40] => ((x1) -> x1) => :spouse_inc)

rename!(df, :r3v13 => :industry)
insertcols!(df, :industry0 => ifelse.(coalesce.(df.industry .< 1000, false), 1, 0))
transform!(df, [:industry] => ((x1) -> string.(x1)) => :industry)

for (x,i) ∈ [(:industry1,1), (:industry2,2), (:industry3,3), (:industry4,4), (:industry5,5), (:industry6,6), (:industry7,7), (:industry8,8), (:industry9,9)]
    insertcols!(df, x => ifelse.(coalesce.(SubString.(df.industry,1,1) .== "$i", false), 1, 0))
end

# CPI for expressing earnings and wba in real dollars
transform!(df, [:date_week_certif_2] => ((x1) -> Dates.format.(x1, "yyyy-mm")) => :date)
sort!(df, [:date])

df2 = readstat("$pathfolder/Data/cpi2.dta")
df2 = DataFrame(df2)
meany = mean(df2[df2.year .== 2010,:avgcpi])
insertcols!(df2, :cpi2010 => meany ./ df2.cpi)
insertcols!(df2, :avgcpi2010 => meany ./ df2.avgcpi)

subset!(df2, [:year] => ((x1) -> x1 .<= 1984))
# date is in unix form, number of month since January 1960 in Stata, Julia Unix is in seconds since midnight on the first of January 1970
# we simply replicate by replacing by hand the 108 long vector of dates
df2[!,:date] = Dates.Date(1976,1,1):Dates.Month(1):Dates.Date(1984,12,1)
transform!(df2, :date => ((x1) -> Dates.format.(x1, "yyyy-mm")) => :date)
sort!(df2, [:date])
select!(df2, [:date, :avgcpi, :cpi, :avgcpi2010, :cpi2010])
df = innerjoin(df, df2, on = [:date])

# we get rid of left and right censored spells (because we only observe spells between xxx
# (depends on the state) and july 31st 1984
subset!(df, [:begin_benf_yr_2] => ((x1) -> x1 .< Date(1984, 1,1)))
mind = minimum(df.date_week_certif_2)
subset!(df, [:begin_benf_yr_2] => ((x1) -> x1 .>= mind))

# In louisiana, we have data from januray 1979 on.
# we only keep non interrupted claims
subset!(df, [:interrupted_claim] => ((x1) -> x1 .== 0))

# State UI parameters: max benefit and min benefit evolution over time...
insertcols!(df, :maxb => 141)
df[!,:maxb] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1979,9,2), false), 149, df.maxb)
df[!,:maxb] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1980,9,7), false), 164, df.maxb)
df[!,:maxb] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1981,9,6), false), 183, df.maxb)
df[!,:maxb] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1982,9,5), false), 205, df.maxb)

insertcols!(df, :minb => 10)

insertcols!(df, :period => 0)
df[!,:period] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1979,1,1), false), 1, df.period)
df[!,:period] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1979,9,2), false), 2, df.period)
df[!,:period] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1980,9,7), false), 3, df.period)
df[!,:period] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1981,9,6), false), 4, df.period)
df[!,:period] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1982,9,5), false), 5, df.period)

# determination of the kink in the assigment variable depends on the fraction
# of hqw taken into account to compute wba:
insertcols!(df, :frac_hqw => 25)

# MAXDURATION and max total benefits in a give benefit year
insertcols!(df, :maxdur => 28)
df[!,:maxdur] = ifelse.(coalesce.(df.begin_benf_yr_2 .>= Date(1983,4,3), false), 26, df.maxdur)

insertcols!(df, :frac_bpw => 2/5)

# This routine cleans the data from a few observations whose
# benefit level is not on the deterministic schedule because of measurement error

subset!(df, [:period] => ((x1) -> x1 .!= 0))
frac_hqw = 25
insertcols!(df, :assignmt => 0)
insertcols!(df, :kink => 0)
insertcols!(df, :kink0 => 0)
insertcols!(df, :kink1 => 0)

maxperiod = maximum(df.period)

for x ∈ 1:maxperiod
    year = minimum(df[df.period .== x,:yr])
    kink2 = convert(Int,mean(df[df.period .== x,:maxb])*frac_hqw)
    kink1 = convert(Int,mean(df[df.period .== x,:minb])*frac_hqw)
    filter!(df -> !(df.hqw < kink2 && df.wba_gross == df.maxb && df.period == x), df)
    df[!,:hqw] = ifelse.(coalesce.(df.period .== x .&& df.hqw .<= kink2 .&& df.hqw .> kink1 .&& df.hqw != df.wba_gross*25, false), df.wba_gross*25, df.hqw)
    df[!,:assignmt] = ifelse.(coalesce.(df.period .== x, false), df.hqw .- kink2, df.assignmt)
    df[!,:kink] = ifelse.(coalesce.(df.period .== x, false), kink2, df.kink)
    df[!,:kink0] = ifelse.(coalesce.(df.period .== x, false), kink1, df.kink0)
    df[!,:kink1] = ifelse.(coalesce.(df.period .== x, false), kink1 - kink2, df.kink1)
    filter!(df -> !(df.hqw > df.kink && df.wba_gross != df.maxb && df.period == x), df)
end

filter!(df -> !(df.hqw == 0), df)

df2 = df
df = df2

# RKD benefit level
insertcols!(df, :period_t => 1)
insertcols!(df, :period_duration => ifelse.(coalesce.(df.begin_benf_yr_2 .< Date(1980,1,1), false),1,missing))
df[!,:period_duration] = ifelse.(coalesce.(df.begin_benf_yr_2 .> Date(1981,9,12) .&& df.begin_benf_yr_2 .< Date(1982,4,1), false),2,df.period_duration)
df[!,:period_duration] = ifelse.(coalesce.(df.begin_benf_yr_2 .> Date(1983,6,19), false),3,df.period_duration)
dropmissing!(df, :period_duration)



# to be able to save as a .dta file (for time purposes as our code loop over load and writing files)
# we save all Date variables in strings and change the type of yr_education and dependents

transform!(df,[:end_claim] => ((x1) -> string.(x1)) => :end_claim)
transform!(df,[:start_claim] => ((x1) -> string.(x1)) => :start_claim)
transform!(df,[:date] => ((x1) -> string.(x1)) => :date)
transform!(df,[:date_week_certif_2] => ((x1) -> string.(x1)) => :date_week_certif_2)
transform!(df,[:begin_benf_yr_2] => ((x1) -> string.(x1)) => :begin_benf_yr_2)

transform!(df, [:yr_education] => ((x1) -> string.(x1)) => :yr_education)
df[!,:yr_education] = ifelse.(coalesce.(df.yr_education .== "All leveles of master and doctoral work", false), "17",df.yr_education)
df[!,:yr_education] = ifelse.(coalesce.(df.yr_education .== "missing", false), missing, df.yr_education)
df[!,:yr_education] = passmissing(x -> parse.(Float64,x)).(df.yr_education)

transform!(df, [:dependents] => ((x1) -> string.(x1)) => :dependents)
df[!,:dependents] = ifelse.(coalesce.(df.dependents .== "equals or exceeds 6", false), "6",df.dependents)
df[!,:dependents] = ifelse.(coalesce.(df.dependents .== "missing", false), missing, df.dependents)
df[!,:dependents] = passmissing(x -> parse.(Float64,x)).(df.dependents)

writestat("$pathfolder/Data/base_2_LA.dta", df)
end



function Table3(pathfolder::String)
#Create an empty database to store results
Table_3 = DataFrame(period= Int64[],
                    outcome= String[],
                    polyorder = Int64[],
                    AIC = Float64[],
                    p_value = Float64[],
                    beta = Float64[],
                    se = Float64[],
                    epsilon = Float64[],
                    se_epsilon = Float64[],
                    Nobs = Int64[])

for period = 1:3
    for outcome ∈ [:duration,:durat_uipaid,:durat_uiclaimed,:age,:yr_education,:male,:dependents]
        for polyorder = 1:3
            println("$period,$outcome,$polyorder")

            # Set up the key parameters

            binsize = 0.1
            h_minus = 1
            h_plus = 1

            # Load the database
            df = readstat("$pathfolder/Data/base_2_LA.dta")
            df = DataFrame(df)
            # Clean the database for regressions

            transform!(df,[:end_claim] => ((x1) -> parse.(Date,x1)) => :end_claim)
            transform!(df,[:start_claim] => ((x1) -> parse.(Date,x1)) => :start_claim)
            transform!(df,[:date] => ((x1) -> parse.(Date,x1)) => :date)
            transform!(df,[:date_week_certif_2] => ((x1) -> parse.(Date,x1)) => :date_week_certif_2)
            transform!(df,[:begin_benf_yr_2] => ((x1) -> parse.(Date,x1)) => :begin_benf_yr_2)

            subset!(df, :wba_gross => x -> x .< df.maxb, skipmissing=true)
            subset!(df, :period_duration => x -> x .== period, skipmissing=true)
            transform!(df, [:maxdur, :frac_bpw, :frac_hqw] => ((x1, x2, x3) -> (x1 .- 1) ./ x2 ./ x3) => :kink_dur)
            transform!(df, [:bpw, :hqw, :kink_dur] => ((x1, x2, x3) -> x1./x2 .- x3) => :assignmt_dur)
            df = df[df.wba_gross .!= 0, [:id, :begin_benf_yr_2, :period, :period_duration, :hqw, :wba_gross, :age, :male, :black, :college, :dependents, :yr_education, :durat_uipaid, :durat_uiclaimed, :maxb, :minb, :duration, :interrupted_claim, :cpi2010, :potduration, :potduration_alltiers, :assignmt, :assignmt_dur, :industry0, :industry1, :industry2, :industry3, :industry4, :industry5, :industry6, :industry7, :industry8, :industry9]]
            df = combine(groupby(df, [:id, :begin_benf_yr_2, :period, :period_duration]; sort = true), [:hqw, :wba_gross, :age, :male, :black, :college, :dependents, :yr_education, :durat_uipaid, :durat_uiclaimed, :maxb, :minb, :duration, :interrupted_claim, :cpi2010, :potduration, :potduration_alltiers, :assignmt, :assignmt_dur, :industry0, :industry1, :industry2, :industry3, :industry4, :industry5, :industry6, :industry7, :industry8, :industry9] .=> mean; renamecols=false)
            transform!(df, [:begin_benf_yr_2] => ((x1) -> Dates.format.(x1, "yyyy-mm-dd")) => :begin_benf_yr_2)
            transform!(df, [:begin_benf_yr_2] => ((x1) -> SubString.(x1,1,4)) => :yr)
            transform!(df, :duration => ((x) -> x ./ 7) => :duration)
            if period == 1
                transform!(df, :assignmt_dur => ((x) -> cut(x, [i for i in -2.0:0.05:2.0], labels=[i for i in -2.0:0.05:1.95], extend=missing)) => :z2_) #when the number is equal to the boundary stata places it in the bracket below while julia places it in the bracket above so we use cuts that are slighlty below their values
                df[3,:z2_] = 1.25
                df[131,:z2_] = -1.25
                df[371,:z2_] = -1.5
                df[482,:z2_] = 1.25
                df[613,:z2_] = -0.75
                df[861,:z2_] = -0.75
                df[885,:z2_] = 1.25
                df[1231,:z2_] = -1.4
                df[1237,:z2_] = -1.5
                df[1300,:z2_] = -1.5
                df[1346,:z2_] = -1.25
                df[1356,:z2_] = 1.0
                df[1466,:z2_] = 1.25
                df[1512,:z2_] = 0.2
                df[1639,:z2_] = -1.15
                df[2496,:z2_] = -1.25
                df[2618,:z2_] = -1.5
                df[2731,:z2_] = 1.25
                df[2988,:z2_] = -0.75
                df[4194,:z2_] = -0.75
                df[4230,:z2_] = 1.25
                df[4313,:z2_] = -1.15
            elseif period == 2
                transform!(df, :assignmt_dur => ((x) -> cut(x, [i for i in -2.0:0.05:2.0], labels=[i for i in -2.0:0.05:1.95], extend=missing)) => :z2_) #when the number is equal to the boundary stata places it in the bracket below while julia places it in the bracket above so we use cuts that are slighlty below their values
                df[131,:z2_] = -0.75
                df[444,:z2_] = 1.0
                df[1175,:z2_] = 1.25
                df[1349,:z2_] = 0.5
                df[1432,:z2_] = 1.25
                df[1630,:z2_] = -0.75
                df[1706,:z2_] = -0.05
            elseif period == 3
                transform!(df, :assignmt_dur => ((x) -> cut(x, [i for i in -2.0:0.05:2.0], labels=[i for i in -2.0:0.05:1.95], extend=missing)) => :z2_) #when the number is equal to the boundary stata places it in the bracket below while julia places it in the bracket above so we use cuts that are slighlty below their values
                df[523,:z2_] = 0.4
                df[776,:z2_] = 1.2
                df[1213,:z2_] = -0.6
                df[1909,:z2_] = 1.25
                df[1965,:z2_] = 2.0
                df[2893,:z2_] = 2.0
                df[3278,:z2_] = 1.1
                df[3885,:z2_] = 1.25
            end
            try
                select!(df, Not([:censored]))
            catch e
                nothing
            end
            try
                transform!(df, :duration => ((x) -> x) => :censored)
                for i in 1:length(df[:,:duration])
                    if df[i,:duration] >= df[i,:potduration_alltiers]
                        df[i,:censored] = 1
                    else
                        df[i,:censored] = 0
                    end
                end
            catch e
                nothing
            end

            # Generate the polynomial regressors

            transform!(df, :assignmt_dur => ((x) -> x) => :overkink)
            for i in 1:length(df[:,:overkink])
                if df[i,:assignmt_dur] > 0
                    df[i,:overkink] = 1
                else
                    df[i,:overkink] = 0
                end
            end

            transform!(df, :assignmt_dur => ((x) -> x) => :v_minus1)
            transform!(df, :assignmt_dur => ((x) -> x.*df.overkink) => :v_over1)

            transform!(df, :assignmt_dur => ((x) -> x.^2) => :v_minus2)
            transform!(df, :assignmt_dur => ((x) -> (x.^2).*df.overkink) => :v_over2)

            transform!(df, :assignmt_dur => ((x) -> x.^3) => :v_minus3)
            transform!(df, :assignmt_dur => ((x) -> (x.^3).*df.overkink) => :v_over3)

            # Save the cleaned data
            CSV.write("$pathfolder/Data/base_reg_LA.csv",df)

            if polyorder == 1 
                # Regression polynomial of degree 1

                # Load the cleaned data
                df = DataFrame(CSV.File("$pathfolder/Data/base_reg_LA.csv"))
                # Run the fixed-effect model

                if outcome == :duration
                    ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uipaid
                    ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uiclaimed
                    ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :age
                    ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :male
                    ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :yr_education
                    ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :dependents
                    ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                end

                AIC= -2*loglikelihood(ols) + 2*(dof(ols) - 1) # Julia dof() systematically reports one more degree of freedom than stata and the aic() function takes dof() as an argument while it should take (dof() - 1) which is the true degree of freedom (to replicate the AIC computed in the paper we therefore need to compute it manually)

                Obs = nobs(ols)
                println("period=$period poly order=$polyorder")

                #Elasticity w.r.t potential duration
                b0 = coef(ols)[3]
                s0 = stderror(HC1(),ols)[3] #Stata reports Hal White (1982) robust variance estimator multiplyed it by n/(n-p), where n is the sample size and p is the number of parameters in the model
                ols = fit(LinearModel,@formula(potduration_alltiers ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                beta = b0/coef(ols)[3]
                se = s0/coef(ols)[3]*(-1)
                meano = mean(skipmissing(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),outcome]))
                println(meano)
                meanpotdur = mean(df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus) .& (df.period_duration .== period),:potduration_alltiers])
                epsilon = beta*meanpotdur/meano
                se_epsilon = se*meanpotdur/meano

                println("BETA=$beta ($se)")
                println("epsilon=$epsilon")

                mini = minimum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                maxa = maximum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                if outcome == :duration
                    if mini != maxa
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :durat_uipaid
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :durat_uiclaimed
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :age
                    if mini != maxa
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :male
                    if mini != maxa
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :yr_education
                    if mini != maxa
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :dependents
                    if mini != maxa
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                end

                # We need to build the F-stat ourselves since we need the robust variance covariance matrix for that: Stata's F-test performs a Wald test with the heteroskedasticity robust variance-covarianec matrix
                F = (coef(ols)[4:length(coef(ols))]'*(vcov(HC1(), ols)[4:length(coef(ols)),4:length(coef(ols))])^(-1)*coef(ols)[4:length(coef(ols))])/(length(coef(ols)) - 3)
                degf_r = dof_residual(ols)
                constraint = length(coef(ols)) - 3
                f = FDist(constraint, degf_r)
                p_value = 1 - cdf(f,F)

                println("Joint significance test for bin dummies")
                println("Regression test F($constraint, $degf_r)=$F ;  Prob> F= $p_value")

                # Store the results polynomial of degree 1

                Temp = DataFrame(period= period,
                                    outcome= "$outcome",
                                    polyorder = polyorder,
                                    AIC = AIC,
                                    p_value = p_value,
                                    beta = beta,
                                    se = se,
                                    epsilon = epsilon,
                                    se_epsilon = se_epsilon,
                                    Nobs = Obs)
                append!(Table_3,Temp)
            elseif polyorder == 2
                # Regression polynomial of degree 2

                # Load the cleaned data
                df = DataFrame(CSV.File("$pathfolder/Data/base_reg_LA.csv"))
                # Run the fixed-effect model

                if outcome == :duration
                    ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uipaid
                    ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uiclaimed
                    ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :age
                    ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :male
                    ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :yr_education
                    ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :dependents
                    ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                end

                AIC= -2*loglikelihood(ols) + 2*(dof(ols) - 1) # Julia dof() systematically reports one more degree of freedom than stata and the aic() function takes dof() as an argument while it should take (dof() - 1) which is the true degree of freedom (to replicate the AIC computed in the paper we therefore need to compute it manually)

                Obs = nobs(ols)
                println("period=$period poly order=$polyorder")

                #Elasticity w.r.t potential duration
                b0 = coef(ols)[3]
                s0 = stderror(HC1(),ols)[3] #Stata reports Hal White (1982) robust variance estimator multiplyed it by n/(n-p), where n is the sample size and p is the number of parameters in the model
                ols = fit(LinearModel,@formula(potduration_alltiers ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                beta = b0/coef(ols)[3]
                se = s0/coef(ols)[3]*(-1)
                meano = mean(skipmissing(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),outcome]))
                println(meano)
                meanpotdur = mean(df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus) .& (df.period_duration .== period),:potduration_alltiers])
                epsilon = beta*meanpotdur/meano
                se_epsilon = se*meanpotdur/meano

                println("BETA=$beta ($se)")
                println("epsilon=$epsilon")

                mini = minimum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                maxa = maximum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                if outcome == :duration
                    if mini != maxa
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :durat_uipaid
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :durat_uiclaimed
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :age
                    if mini != maxa
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :male
                    if mini != maxa
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :yr_education
                    if mini != maxa
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :dependents
                    if mini != maxa
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                end

                # We need to build the F-stat ourselves since we need the robust variance covariance matrix for that: Stata's F-test performs a Wald test with the heteroskedasticity robust variance-covarianec matrix
                F = (coef(ols)[6:length(coef(ols))]'*(vcov(HC1(), ols)[6:length(coef(ols)),6:length(coef(ols))])^(-1)*coef(ols)[6:length(coef(ols))])/(length(coef(ols)) - 5)
                degf_r = dof_residual(ols)
                constraint = length(coef(ols)) - 5
                f = FDist(constraint, degf_r)
                p_value = 1 - cdf(f,F)

                println("Joint significance test for bin dummies")
                println("Regression test F($constraint, $degf_r)=$F ;  Prob> F= $p_value")

                # Store the results polynomial of degree 2

                Temp = DataFrame(period= period,
                                    outcome= "$outcome",
                                    polyorder = polyorder,
                                    AIC = AIC,
                                    p_value = p_value,
                                    beta = beta,
                                    se = se,
                                    epsilon = epsilon,
                                    se_epsilon = se_epsilon,
                                    Nobs = Obs)
                append!(Table_3,Temp)
            elseif polyorder == 3
                # Regression polynomial of degree 3

                # Load the cleaned data
                df = DataFrame(CSV.File("$pathfolder/Data/base_reg_LA.csv"))
                # Run the fixed-effect model

                if outcome == :duration
                    ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uipaid
                    ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :durat_uiclaimed
                    ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :age
                    ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :male
                    ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :yr_education
                    ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                elseif outcome == :dependents
                    ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                end

                AIC= -2*loglikelihood(ols) + 2*(dof(ols) - 1) # Julia dof() systematically reports one more degree of freedom than stata and the aic() function takes dof() as an argument while it should take (dof() - 1) which is the true degree of freedom (to replicate the AIC computed in the paper we therefore need to compute it manually)

                Obs = nobs(ols)
                println("period=$period poly order=$polyorder")

                #Elasticity w.r.t potential duration
                b0 = coef(ols)[3]
                s0 = stderror(HC1(),ols)[3] #Stata reports Hal White (1982) robust variance estimator multiplyed it by n/(n-p), where n is the sample size and p is the number of parameters in the model
                ols = fit(LinearModel,@formula(potduration_alltiers ~ v_minus1 + v_over1), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:])
                beta = b0/coef(ols)[3]
                se = s0/coef(ols)[3]*(-1)
                meano = mean(skipmissing(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),outcome]))
                println(meano)
                meanpotdur = mean(df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus) .& (df.period_duration .== period),:potduration_alltiers])
                epsilon = beta*meanpotdur/meano
                se_epsilon = se*meanpotdur/meano

                println("BETA=$beta ($se)")
                println("epsilon=$epsilon")

                mini = minimum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                maxa = maximum(df[(df.v_minus1 .>= -2*binsize) .& (df.v_over1 .< 2*binsize) .& (df.period_duration .== period),:period_duration])
                if outcome == :duration
                    if mini != maxa
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(duration ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :durat_uipaid
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uipaid ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :durat_uiclaimed
                    if mini != maxa
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(durat_uiclaimed ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end    
                elseif outcome == :age
                    if mini != maxa
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(age ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :male
                    if mini != maxa
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(male ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3  + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end  
                elseif outcome == :yr_education
                    if mini != maxa
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(yr_education ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                elseif outcome == :dependents
                    if mini != maxa
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_ + period_duration), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding(), :period_duration => DummyCoding()))
                    else
                        ols = fit(LinearModel, @formula(dependents ~ v_minus1 + v_over1 + v_minus2 + v_over2 + v_minus3 + v_over3 + z2_), df[(df.v_minus1 .>= -h_minus) .& (df.v_over1 .< h_plus),:], contrasts = Dict(:z2_ => DummyCoding()))
                    end 
                end

                # We need to build the F-stat ourselves since we need the robust variance covariance matrix for that: Stata's F-test performs a Wald test with the heteroskedasticity robust variance-covarianec matrix
                F = (coef(ols)[8:length(coef(ols))]'*(vcov(HC1(), ols)[8:length(coef(ols)),8:length(coef(ols))])^(-1)*coef(ols)[8:length(coef(ols))])/(length(coef(ols)) - 7)
                degf_r = dof_residual(ols)
                constraint = length(coef(ols)) - 7
                f = FDist(constraint, degf_r)
                p_value = 1 - cdf(f,F)

                println("Joint significance test for bin dummies")
                println("Regression test F($constraint, $degf_r)=$F ;  Prob> F= $p_value")

                # Store the results polynomial of degree 3

                Temp = DataFrame(period= period,
                                    outcome= "$outcome",
                                    polyorder = polyorder,
                                    AIC = AIC,
                                    p_value = p_value,
                                    beta = beta,
                                    se = se,
                                    epsilon = epsilon,
                                    se_epsilon = se_epsilon,
                                    Nobs = Obs)
                append!(Table_3,Temp)
            end
        end
    end
end

CSV.write("$pathfolder/Results/Table_3.csv", Table_3)

Table_3 = DataFrame(CSV.File("$pathfolder/Results/Table_3.csv"))

Table_3[:, :minAIC] .= false
for i = 1:3
    for outcome ∈ [:duration,:durat_uipaid,:durat_uiclaimed,:age,:male,:yr_education,:dependents]
        Table_3[(Table_3.outcome .== "$outcome") .& (Table_3.period .== i),:] = transform(Table_3[(Table_3.outcome .== "$outcome") .& (Table_3.period .== i),:], :AIC => ((x) -> x .== minimum(Table_3[(Table_3.outcome .== "$outcome") .& (Table_3.period .== i),:AIC])) => :minAIC)
    end
end

subset!(Table_3, :minAIC => x -> x .== true)
Table_3 = Table_3[:, [:period, :beta, :se, :epsilon, :se_epsilon, :polyorder, :p_value, :Nobs]]

Table_3_1 = Table_3[Table_3.period .== 1,:]
Table_3_1[:,:period] = [i for i ∈ 1:7]
for outcome ∈ [:period,:beta,:se,:epsilon,:se_epsilon,:polyorder,:p_value,:Nobs]
    transform!(Table_3_1, outcome => (x -> string.(round.(x, digits = 3))) => outcome)
end
Table_3_1 = permutedims(Table_3_1, 1)
Table_3_1[:,:period] = ["β", "", "ε_β", "", "Opt. Poly", "p-value", "Observations"]

Table_3_2 = Table_3[Table_3.period .== 2,:]
Table_3_2[:,:period] = [i for i ∈ 1:7]
for outcome ∈ [:period,:beta,:se,:epsilon,:se_epsilon,:polyorder,:p_value,:Nobs]
    transform!(Table_3_2, outcome => (x -> string.(round.(x, digits = 3))) => outcome)
end
Table_3_2 = permutedims(Table_3_2, 1)
Table_3_2[:,:period] = ["β", "", "ε_β", "", "Opt. Poly", "p-value", "Observations"]

Table_3_3 = Table_3[Table_3.period .== 3,:]
Table_3_3[:,:period] = [i for i ∈ 1:7]
for outcome ∈ [:period,:beta,:se,:epsilon,:se_epsilon,:polyorder,:p_value,:Nobs]
    transform!(Table_3_3, outcome => (x -> string.(round.(x, digits = 3))) => outcome)
end
Table_3_3 = permutedims(Table_3_3, 1)
Table_3_3[:,:period] = ["β", "", "ε_β", "", "Opt. Poly", "p-value", "Observations"]

FinalTable = append!(Table_3_1,Table_3_2)
FinalTable = append!(FinalTable,Table_3_3)
println(FinalTable)
return latexify(FinalTable, env = :tabular, head = ["","Durationofinitialspell","DurationofUIpaid","DurationofUIclaimed","Age","Yearsofeducation","Male","Dependents"]) |> print
end

end
