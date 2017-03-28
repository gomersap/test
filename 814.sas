/* OA Official Stats SAS code
The code is divided into 11 sections and the following are the areas which change based on the two macro variables below:
   Section 3:  Change the data set ie year and month eg pers201205 for May 2012 data
   Section 10: Change the location of the output (if necessary) and the name of the folder
               and the quarter (eg February 2011) in the title of the table. 
   Section 11: In the last bit of the code subsection 'QA Report' change the location of
               the output.
*/

* SECTION 1: CONNECTING TO THE SERVER AND CREATING LIBRARY LINKS TO THE DATA;

%let quarter=Feb2012;  /*Quarter being ran*/
%let persqtr=201202;   /*Relevant person dataset for quarter*/

*SECTION 2: CREATING MACRO VARIABLES TO BE USED IN THE ROUNDING ALGORITHMS ;


%macro create(n);                       /* These next three macros are involved with  */
 %do i=1 %to &n;                        /*  the controlled rounding of COA  		  */
  varr&i=ranuni(0);                     /*  data - to protect small counts  		  */
  var&i=0;                              
 %end;                                  
%mend create;
%macro results;
%do i=1 %to 5;
 diff&i=var&i-varu&i;
%end;
%mend;
%macro resultsa;
%do i=1 %to 5;
 diffa&i=var&i-varu&i;
%end;
%mend;

* SECTION 3: ACCESSING THE BENEFITS DATA ;

*  Select working age key out of work benefit claimants from the frozen dataset; 
data kowb ; 
set nsdata.pers&persqtr. (keep=ccnino cccoa cclsoa ccdz ccward2003 ccla ccgor ccstatgp ccclient);
where ccclient=2 and ccstatgp in (1,2,3,5) ;
if cclsoa=' ' then cclsoa=ccdz;
run;
 
* SECTION 4: PREPARING DATA TO CREATE COUNTS FOR THE BENEFIT CLAIMANTS ;

*  Remove duplicates (there shouldnt be any) just incase;
proc sort data=kowb nodupkey;
by ccnino;
run;

/*Table at COA*/
proc sort data=kowb;
by cccoa;
run;

*  Use a counting algorithm to obtain the coa counts in each stat group;
*  Add up the stat groups to get a key out of work benefits total;
data kowbcoa (keep=cccoa total stat1 stat2 stat3 stat4);
set kowb;
by cccoa;
length total stat1 stat2 stat3 stat4 6.;
retain total stat1 stat2 stat3 stat4;

if first.cccoa then do;
				total=0;stat1=0;stat2=0;stat3=0;stat4=0;stat5=0;
				end;

if ccstatgp=1 then stat1=stat1+1;
else if ccstatgp=2 then stat2=stat2+1;
else if ccstatgp=3 then stat3=stat3+1;
else if ccstatgp=5 then stat4=stat4+1;
total=stat1+stat2+stat3+stat4;
if last.cccoa then output;
run;

*Merge the lookup to the coa counts and set any missings to 0.;
*This ensures we have every coa represented in the counts;
data lookup (rename=(coa=cccoa));
set postcode.coalookuptable_all_geogs_new  (keep=coa);
run;

data kowbcoa;
merge kowbcoa lookup (in=a);
by cccoa;
if a;
run;
 
data kowb_coa_unrounded;  
set kowbcoa;
by cccoa;
if total=. then total=0;
if stat1=. then stat1=0;
if stat2=. then stat2=0;
if stat3=. then stat3=0;
if stat4=. then stat4=0;
run;

proc sort data=kowb_coa_unrounded;
by cccoa;
run;

* SECTION 5: PREPARING DATA FOR PROBABILISTIC ROUNDING;


*  Rename the variables to be put through a generic probabilistic rounding process; 
data temp;								
set kowb_coa_unrounded;														
format varr1-varr5 4.3;
rename total=varu1;  * "u" represents unrounded;
rename stat1=varu2;
rename stat2=varu3;
rename stat3=varu4;
rename stat4=varu5;
%create(5); *  This creates five columns of zeros ready to be populated with numbers;
run;


* SECTION 6: PROBABILISTIC ROUNDING ;


*  Run the probabilistic rounding algorithm to populate "var1" etc with the prob rounded figures;

*  This works by first checking to see whether or not the unrounded value is a zero or five, in which
   case leave it as it is.  Otherwise automatically calculate what the unrounded value ends in (eg 1 or 6)
   and use the uniform [0,1] random number as comparison to round up or down.  Values ending in 1 will
   be transformed to 0.2, of which there is an 80% chance that the random number will be larger than this.
   So 80% of the time these values have 1 taken away and so are rounded down.  20% of the time the values
   will have 4 added and so will be rounded up.  Similarly for all other digits 2 through to 9.;

*  Also do a quick check to see that the prob rounded figures are within five of the unrounded ones;
*  Prob_check should contain zero observations;

data temp2 (drop=varr1-varr5 column) prob_check;
set temp;
format varu1 varu2 varu3 varu4 varu5
	   var1 var2 var3 var4 var5 8.; 
array rn {5} varr1-varr5;
array rd {5} var1-var5;
array un {5} varu1-varu5;
  do column=1 to 5;

        if ((un{column}/5)-floor(un{column}/5))=0 then rd{column}=un{column};
            else if rn{column}>=((un{column}/5)-floor(un{column}/5)) then do;
                        if 0.19<((un{column}/5)-floor(un{column}/5))<0.21 then rd{column}=un{column}-1;
                   else if 0.39<((un{column}/5)-floor(un{column}/5))<0.41 then rd{column}=un{column}-2;
                   else if 0.59<((un{column}/5)-floor(un{column}/5))<0.61 then rd{column}=un{column}-3;
                   else if 0.79<((un{column}/5)-floor(un{column}/5))<0.81 then rd{column}=un{column}-4;
            end;

            else if rn{column}< ((un{column}/5)-floor(un{column}/5)) then do;
                        if 0.19<((un{column}/5)-floor(un{column}/5))<0.21 then rd{column}=un{column}+4;
                   else if 0.39<((un{column}/5)-floor(un{column}/5))<0.41 then rd{column}=un{column}+3;
                   else if 0.59<((un{column}/5)-floor(un{column}/5))<0.61 then rd{column}=un{column}+2;
                   else if 0.79<((un{column}/5)-floor(un{column}/5))<0.81 then rd{column}=un{column}+1;
            end;
 end;
diff=var1-sum(of var2-var5);  *  Compute a variable for the difference between the total and the stat groups;
%results;  *  This computes the difference between the prob rounded and unrounded figures;
output temp2;
if diff1>=5 or diff2>=5 or diff3>=5 or diff4>=5 or diff5>=5 then output prob_check;
run;


* SECTION 7: CONTROLLED ROUNDING ;

*  Use proc contents to obtain the number of observations in prob_check;
*  This will be used to form part of the QA report later;
proc contents data=prob_check (keep=cccoa) noprint out=contents_prob (keep=memname nobs);run;

*  Perform a controlled rounding algorithm;
*  This works by adjusting the desired number of categories by +/- 5 so that the total is matched;
*  It scans whether or not the category was rounded up or down in the probabilistic step so that
   there are no categories which are altered by more than 5;

*  Note that it tends to adjust the first category the most and so is probably biased;
*  The extent of the bias is unknown and requires further investigation;
data temp3;
set temp2;
if diff=20 then do;
var2=var2+5;var3=var3+5;var4=var4+5;var5=var5+5;
end;

if diff=15 then do;
if diff2<0 and diff3<0 and diff4<0 then do;var2=var2+5;var3=var3+5;var4=var4+5;end;
else if diff2<0 and diff3<0 and diff5<0 then do;var2=var2+5;var3=var3+5;var5=var5+5;end;
else if diff2<0 and diff4<0 and diff5<0 then do;var2=var2+5;var4=var4+5;var5=var5+5;end;
else if diff3<0 and diff4<0 and diff5<0 then do;var3=var3+5;var4=var4+5;var5=var5+5;end;
end;

if diff=10 then do;
if diff2<0 and diff3<0 then do;var2=var2+5;var3=var3+5;;end;
else if diff2<0 and diff4<0 then do;var2=var2+5;var4=var4+5;end;
else if diff2<0 and diff5<0 then do;var2=var2+5;var5=var5+5;end;
else if diff3<0 and diff4<0 then do;var3=var3+5;var4=var4+5;end;
else if diff3<0 and diff5<0 then do;var3=var3+5;var5=var5+5;end;
else if diff4<0 and diff5<0 then do;var4=var4+5;var5=var5+5;end;
end;

if diff=5 then do;
if diff2<0 then do;var2=var2+5;end;
else if diff3<0 then do;var3=var3+5;end;
else if diff4<0 then do;var4=var4+5;end;
else if diff5<0 then do;var5=var5+5;end;
end;

if diff=-20 then do;
var2=var2-5;var3=var3-5;var4=var4-5;var5=var5-5;
end;

if diff=-15 then do;
if diff2>0 and diff3>0 and diff4>0 then do;var2=var2-5;var3=var3-5;var4=var4-5;end;
else if diff2>0 and diff3>0 and diff5>0 then do;var2=var2-5;var3=var3-5;var5=var5-5;end;
else if diff2>0 and diff4>0 and diff5>0 then do;var2=var2-5;var4=var4-5;var5=var5-5;end;
else if diff3>0 and diff4>0 and diff5>0 then do;var3=var3-5;var4=var4-5;var5=var5-5;end;
end;

if diff=-10 then do;
if diff2>0 and diff3>0 then do;var2=var2-5;var3=var3-5;;end;
else if diff2>0 and diff4>0 then do;var2=var2-5;var4=var4-5;end;
else if diff2>0 and diff5>0 then do;var2=var2-5;var5=var5-5;end;
else if diff3>0 and diff4>0 then do;var3=var3-5;var4=var4-5;end;
else if diff3>0 and diff5>0 then do;var3=var3-5;var5=var5-5;end;
else if diff4>0 and diff5>0 then do;var4=var4-5;var5=var5-5;end;
end;

if diff=-5 then do;
if diff2>0 then do;var2=var2-5;end;
else if diff3>0 then do;var3=var3-5;end;
else if diff4>0 then do;var4=var4-5;end;
else if diff5>0 then do;var5=var5-5;end;
end;
%resultsa; *  This computes the difference between the control rounded figures and the unrounded;
difftot=var1-sum(of var2-var5);  *  Create a variable which shows the difference between the total and the control rounded stat groups;
run;

*SECTION 8: CHECKING TO SEE WHETHER CONTROLLED ROUNDING WORKED;

*  Check that the control rounding process worked;
*  Difftot should be zero as the purpose of control rounding was to match the total;
*  Again, check that the stat groups have been rounded by no more than 5;
data problems_control_rounding;				
set temp3;													
where difftot ne 0 or abs(diffa1) ge 5 or abs(diffa2) ge 5 or abs(diffa3) ge 5 or abs(diffa4) ge 5 
      or abs(diffa5) ge 5;
run;

*  Form a dataset to contribute to the QA report;
proc contents data=problems_control_rounding (keep=cccoa) noprint out=contents_contr (keep=memname nobs);run;

*  Take a copy of the probabilistically rounded figures for information;
data kowb_coa_probrounded (rename=(var1=owb var2=jsa var3=ib_esa var4=lp var5=oth));
set temp2 (keep=cccoa var1-var5);
run;

*  Rename the variables for the control rounded figures;
data kowb_coa_controunded (rename=(var1=owb var2=jsa var3=ib_esa var4=lp var5=oth));
set temp3 (keep=cccoa var1-var5);
run;


* SECTION 9: ATTACHING LABELS ON ROUNDED DATA ;

*  Merge on a bunch of higher spatial level codes;
data final_lookup (drop=data_zone rename=(coa=cccoa lsoacode=cclsoa ward_code=ccward2003 la2009=ccla gor_code=ccgor));
set postcode.coalookuptable_all_geogs_new (keep=coa lsoacode ward_code ward_name la2009 la2009_name gor_code gor_name data_zone);
if lsoacode=' ' then lsoacode=data_zone;
run;

data kowb_coa_unrounded (rename=(total=owb stat1=jsa stat2=ib_esa stat3=lp stat4=oth));
merge kowb_coa_unrounded final_lookup (in=a);
by cccoa;
if a;
run;

data kowb_coa_final;
merge kowb_coa_controunded final_lookup (in=a);
by cccoa;
if a;
run;

* SECTION 10 : PRODUCING OUTPUT OF THE ROUNDED FIGURES BY GOVERNMENT OFFICE REGION ;

* Producing output of the rounded figures split by Goverment region ;
* rn stands for government office region eg rn_1 is the first gov region ;

 data rn_1 rn_2 rn_3 rn_4 rn_5 rn_6 rn_7 rn_8 rn_9 rn_10 rn_11 ;
 set kowb_coa_final;

if ccgor='A' then output rn_1;
else if ccgor='B' then output rn_2;
else if ccgor='D' then output rn_3;
else if ccgor='E' then output rn_4;
else if ccgor='F' then output rn_5;
else if ccgor='G' then output rn_6;
else if ccgor='H' then output rn_7;
else if ccgor='J' then output rn_8;
else if ccgor='K' then output rn_9;
else if ccgor='W' then output rn_10;
else if ccgor='X' then output rn_11;
run;


* Macro to produce figures for the 10 Government regions excluding Scotland;

%macro try ;
%do i=1 %to 10;

ods listing close ;
ods html file="\\dfz72623\Folders\CLIENT_STATISTICS\Live_Running\Dissemination\COA_workless\&quarter.\rn_&i..xls"  style=minimal ;
proc print data=work.rn_&i noobs label STYLE(HEADER)= {FONT_WEIGHT=BOLD Background=light grey};
    var ccgor gor_name ccla la2009_name ccward2003 ward_name cclsoa cccoa jsa ib_esa lp oth owb ;
    label      ccgor='Government Region Code'
            gor_name='Government Region Name'
                ccla='Local Authority Code'
         la2009_name='Local Authority Name' 
          ccward2003='Ward Code'
           ward_name='Ward Name'
		         jsa='Job Seeker'
			  ib_esa='ESA and incapacity benefits'
                  lp='Lone Parent' 
                 oth='Others on income related benefit'
                 owb=' "Total" Out of Work Benefits' ;
              
   Title 'Out of Work Benefits Claimants in Census Output Areas: February 2012 ' ;
   
run;
%end;
%mend ;
%try ;
ods html close ;
ods listing ;


* SECTION 11: QUALITY ASSURANCE CHECKS:


*  Think about which quality assurance checks you want;
*  1. Has the probabilitic rounding worked? (ie are the rounded numbers within 5 of the unrounded);
*  2. Has the controlled rounding worked? (ie do the breakdowns sum to the total and are the breakdowns within 5 of the unrounded);
*  3. Do the unrounded coa figures aggregate exactly to the unrounded lsoa figures?
*  4. Do the unrounded coa figures aggregate exactly to the unrounded ward figures?
*  5. Do the unrounded coa figures aggregate exactly to the unrounded la figures?
*  6. Do the unrounded coa figures aggregate exactly to the unrounded gor figures?
*  7. How many Output Areas have missing values?

*  If you can satisfy 3-6 then this confirms consistency with the already published National Stats
   Then all you need to verfiy is that 1&2 are satisfied to make sure the rounding processes have worked
   as expected.  Then combining this with an error free log gives a high level of assurance in the figures
   (purely from a single date processing perspective, this ignores time-series considerations at COA level);

*  Is check 7 so important?  It probably is, and comparisons with previous quarters are required;

*  Further issues include use of a final template.  This only needs to be properly quality assured
   once and this can be used thereafter (in a variety of ways).  Another issue is the underlying
   properties of the address matching process and volatility of COA changes.  This is a big quality
   assurance challenge and you may wish to take confidence from an lsoa analysis performed by IFD.;

/***********************/
*  CHECK 1              ;
/***********************/
*  Observe the "contents_prob" dataset created earlier;


/***********************/
*   CHECK 2             ;
/***********************/
*  Observe the "contents_prob" dataset created earlier;


/***********************/
*  CHECK 3              ;
/***********************/
/*Table at LSOA*/
proc sort data=kowb;
by cclsoa;
run;

*  Use a counting algorithm to obtain the lsoa counts in each stat group;
*  Add up the stat groups to get a key out of work benefits total;
data kowblsoa (keep=cclsoa total stat1 stat2 stat3 stat4);
set kowb;
by cclsoa;
length total stat1 stat2 stat3 stat4 6.;
retain total stat1 stat2 stat3 stat4;

if first.cclsoa then do;
				total=0;stat1=0;stat2=0;stat3=0;stat4=0;stat5=0;
				end;

if ccstatgp=1 then stat1=stat1+1;
else if ccstatgp=2 then stat2=stat2+1;
else if ccstatgp=3 then stat3=stat3+1;
else if ccstatgp=5 then stat4=stat4+1;
total=stat1+stat2+stat3+stat4;
if last.cclsoa then output;
run;

*Merge the lookup to the lsoa counts and set any missings to 0.;
*This ensures we have every coa represented in the counts;
data lookup_lsoa (rename=(lsoacode=cclsoa));
set postcode.coalookuptable_all_geogs_new (keep=lsoacode data_zone);
if lsoacode=' ' then lsoacode=data_zone;
run;

proc sort data=lookup_lsoa nodupkey;
by cclsoa;
run;

data kowblsoa;
merge kowblsoa lookup_lsoa (in=a);
by cclsoa;
if a;
run;
 
data kowb_lsoa_unrounded (rename=(total=owb stat1=jsa stat2=ib_esa stat3=lp stat4=oth));  
set kowblsoa;
by cclsoa;
if total=. then total=0;
if stat1=. then stat1=0;
if stat2=. then stat2=0;
if stat3=. then stat3=0;
if stat4=. then stat4=0;
run;

*Aggregate the unrounded COA figures up to LSOA level;
proc sort data=kowb_coa_unrounded;
by cclsoa;
run;

data coa_upto_lsoa (keep=cclsoa cowb cjsa cib_esa clp coth);
set kowb_coa_unrounded;
by cclsoa;
retain cowb cjsa cib_esa clp coth;
if first.cclsoa then do;
	cowb=0; cjsa=0; cib_esa=0; clp=0; coth=0;
	end;

cowb=cowb+owb; cjsa=cjsa+jsa; cib_esa=cib_esa+ib_esa; clp=clp+lp; coth=coth+oth;
if last.cclsoa then output;
run;

* Merge with the unrounded LSOA figures and compute the differences;
data coa_lsoa_check;
merge coa_upto_lsoa (in=a) kowb_lsoa_unrounded (in=b);
by cclsoa;
if a and b;
diff_owb=owb-cowb; diff_jsa=jsa-cjsa; diff_ib_esa=ib_esa-cib_esa;
diff_lp=lp-clp; diff_oth=oth-coth;
if diff_owb ne 0 or diff_jsa ne 0 or diff_ib_esa ne 0 or diff_lp ne 0 or diff_oth ne 0 then output;
run;

* Obtain a contents report to tell you that there were no differences;
proc contents data=coa_lsoa_check (keep=cclsoa) noprint out=contents_lsoa (keep=memname nobs); run;


/***********************/
*  CHECK 4              ;
/***********************/
/*Table at WARD*/
proc sort data=kowb;
by ccward2003;
run;

*  Use a counting algorithm to obtain the lsoa counts in each stat group;
*  Add up the stat groups to get a key out of work benefits total;
data kowbward (keep=ccward2003 total stat1 stat2 stat3 stat4);
set kowb;
by ccward2003;
length total stat1 stat2 stat3 stat4 6.;
retain total stat1 stat2 stat3 stat4;

if first.ccward2003 then do;
				total=0;stat1=0;stat2=0;stat3=0;stat4=0;stat5=0;
				end;

if ccstatgp=1 then stat1=stat1+1;
else if ccstatgp=2 then stat2=stat2+1;
else if ccstatgp=3 then stat3=stat3+1;
else if ccstatgp=5 then stat4=stat4+1;
total=stat1+stat2+stat3+stat4;
if last.ccward2003 then output;
run;

*Merge the lookup to the lsoa counts and set any missings to 0.;
*This ensures we have every coa represented in the counts;
data lookup_ward (rename=(ward_code=ccward2003));
set postcode.coalookuptable_all_geogs_new (keep=ward_code);
run;

proc sort data=lookup_ward nodupkey;
by ccward2003;
run;

data kowbward;
merge kowbward lookup_ward (in=a);
by ccward2003;
if a;
run;
 
data kowb_ward_unrounded (rename=(total=owb stat1=jsa stat2=ib_esa stat3=lp stat4=oth));  
set kowbward;
by ccward2003;
if total=. then total=0;
if stat1=. then stat1=0;
if stat2=. then stat2=0;
if stat3=. then stat3=0;
if stat4=. then stat4=0;
run;

*Aggregate the unrounded COA figures up to LSOA level;
proc sort data=kowb_coa_unrounded;
by ccward2003;
run;

data coa_upto_ward (keep=ccward2003 cowb cjsa cib_esa clp coth);
set kowb_coa_unrounded;
by ccward2003;
retain cowb cjsa cib_esa clp coth;
if first.ccward2003 then do;
	cowb=0; cjsa=0; cib_esa=0; clp=0; coth=0;
	end;

cowb=cowb+owb; cjsa=cjsa+jsa; cib_esa=cib_esa+ib_esa; clp=clp+lp; coth=coth+oth;
if last.ccward2003 then output;
run;

* Merge with the unrounded LSO figures and compute the differences;
data coa_ward_check;
merge coa_upto_ward (in=a) kowb_ward_unrounded (in=b);
by ccward2003;
if a and b;
diff_owb=owb-cowb; diff_jsa=jsa-cjsa; diff_ib_esa=ib_esa-cib_esa;
diff_lp=lp-clp; diff_oth=oth-coth;
if diff_owb ne 0 or diff_jsa ne 0 or diff_ib_esa ne 0 or diff_lp ne 0 or diff_oth ne 0 then output;
run;

* Obtain a contents report to tell you that there were no differences;
proc contents data=coa_ward_check (keep=ccward2003) noprint out=contents_ward (keep=memname nobs); run;


/***********************/
*  CHECK 5              ;
/***********************/
/*Table at LA*/
proc sort data=kowb;
by ccla;
run;

*  Use a counting algorithm to obtain the lsoa counts in each stat group;
*  Add up the stat groups to get a key out of work benefits total;
data kowbla (keep=ccla total stat1 stat2 stat3 stat4);
set kowb;
by ccla;
length total stat1 stat2 stat3 stat4 6.;
retain total stat1 stat2 stat3 stat4;

if first.ccla then do;
				total=0;stat1=0;stat2=0;stat3=0;stat4=0;stat5=0;
				end;

if ccstatgp=1 then stat1=stat1+1;
else if ccstatgp=2 then stat2=stat2+1;
else if ccstatgp=3 then stat3=stat3+1;
else if ccstatgp=5 then stat4=stat4+1;
total=stat1+stat2+stat3+stat4;
if last.ccla then output;
run;

*Merge the lookup to the lsoa counts and set any missings to 0.;
*This ensures we have every coa represented in the counts;
data lookup_la (rename=(la2009=ccla));
set postcode.coalookuptable_all_geogs_new (keep=la2009);
run;

proc sort data=lookup_la nodupkey;
by ccla;
run;

data kowbla;
merge kowbla lookup_la (in=a);
by ccla;
if a;
run;
 
data kowb_la_unrounded (rename=(total=owb stat1=jsa stat2=ib_esa stat3=lp stat4=oth));  
set kowbla;
by ccla;
if total=. then total=0;
if stat1=. then stat1=0;
if stat2=. then stat2=0;
if stat3=. then stat3=0;
if stat4=. then stat4=0;
run;

*Aggregate the unrounded COA figures up to LSOA level;
proc sort data=kowb_coa_unrounded;
by ccla;
run;

data coa_upto_la(keep=ccla cowb cjsa cib_esa clp coth);
set kowb_coa_unrounded;
by ccla;
retain cowb cjsa cib_esa clp coth;
if first.ccla then do;
	cowb=0; cjsa=0; cib_esa=0; clp=0; coth=0;
	end;

cowb=cowb+owb; cjsa=cjsa+jsa; cib_esa=cib_esa+ib_esa; clp=clp+lp; coth=coth+oth;
if last.ccla then output;
run;

* Merge with the unrounded LSO figures and compute the differences;
data coa_la_check;
merge coa_upto_la (in=a) kowb_la_unrounded (in=b);
by ccla;
if a and b;
diff_owb=owb-cowb; diff_jsa=jsa-cjsa; diff_ib_esa=ib_esa-cib_esa;
diff_lp=lp-clp; diff_oth=oth-coth;
if diff_owb ne 0 or diff_jsa ne 0 or diff_ib_esa ne 0 or diff_lp ne 0 or diff_oth ne 0 then output;
run;

* Obtain a contents report to tell you that there were no differences;
proc contents data=coa_la_check (keep=ccla) noprint out=contents_la (keep=memname nobs); run;


/***********************/
*  CHECK 6              ;
/***********************/
/*Table at GOR*/
proc sort data=kowb;
by ccgor;
run;

*  Use a counting algorithm to obtain the lsoa counts in each stat group;
*  Add up the stat groups to get a key out of work benefits total;
data kowbgor (keep=ccgor total stat1 stat2 stat3 stat4);
set kowb;
by ccgor;
length total stat1 stat2 stat3 stat4 6.;
retain total stat1 stat2 stat3 stat4;

if first.ccgor then do;
				total=0;stat1=0;stat2=0;stat3=0;stat4=0;stat5=0;
				end;

if ccstatgp=1 then stat1=stat1+1;
else if ccstatgp=2 then stat2=stat2+1;
else if ccstatgp=3 then stat3=stat3+1;
else if ccstatgp=5 then stat4=stat4+1;
total=stat1+stat2+stat3+stat4;
if last.ccgor then output;
run;

*Merge the lookup to the lsoa counts and set any missings to 0.;
*This ensures we have every coa represented in the counts;
data lookup_gor (rename=(gor_code=ccgor));
set postcode.coalookuptable_all_geogs_new (keep=gor_code);
run;

proc sort data=lookup_gor nodupkey;
by ccgor;
run;

data kowbgor;
merge kowbgor lookup_gor (in=a);
by ccgor;
if a;
run;
 
data kowb_gor_unrounded (rename=(total=owb stat1=jsa stat2=ib_esa stat3=lp stat4=oth));  
set kowbgor;
by ccgor;
if total=. then total=0;
if stat1=. then stat1=0;
if stat2=. then stat2=0;
if stat3=. then stat3=0;
if stat4=. then stat4=0;
run;

*Aggregate the unrounded COA figures up to LSOA level;
proc sort data=kowb_coa_unrounded;
by ccgor;
run;

data coa_upto_gor (keep=ccgor cowb cjsa cib_esa clp coth);
set kowb_coa_unrounded;
by ccgor;
retain cowb cjsa cib_esa clp coth;
if first.ccgor then do;
	cowb=0; cjsa=0; cib_esa=0; clp=0; coth=0;
	end;

cowb=cowb+owb; cjsa=cjsa+jsa; cib_esa=cib_esa+ib_esa; clp=clp+lp; coth=coth+oth;
if last.ccgor then output;
run;

* Merge with the unrounded LSO figures and compute the differences;
data coa_gor_check;
merge coa_upto_gor (in=a) kowb_gor_unrounded (in=b);
by ccgor;
if a and b;
diff_owb=owb-cowb; diff_jsa=jsa-cjsa; diff_ib_esa=ib_esa-cib_esa;
diff_lp=lp-clp; diff_oth=oth-coth;
if diff_owb ne 0 or diff_jsa ne 0 or diff_ib_esa ne 0 or diff_lp ne 0 or diff_oth ne 0 then output;
run;

* Obtain a contents report to tell you that there were no differences;
proc contents data=coa_gor_check (keep=ccgor) noprint out=contents_gor (keep=memname nobs); run;

/*********************/
*   QA REPORT         ;
/*********************/

* BRING ALL OF THE QUALITY ASSURANCE CHECKS TOGETHER IN ONE DATASET;
* Every QA dataset should contain no observations;
data qa_report;
set contents_prob contents_contr contents_lsoa contents_ward contents_la contents_gor;
run;

* Download the QA report into a spreadsheet to be saved and observed;
* The SAS macro below produces the QR report;
* Make sure an Excel file is created and this should be named QA_Report; 

ods listing close ;
ods html file="\\dfz72739\Folders\CLIENT_STATISTICS\Live_Running\Dissemination\COA_workless\&quarter\QA_Report.xls"  style=minimal ;
title "QA report COA worklessness &quarter - Every QA dataset should contain no observations";
PROC PRINT DATA=qa_report noobs;
RUN;
   
run;
ods html close ;
ods listing ;



 
