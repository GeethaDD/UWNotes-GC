/**
* @description JSON Structure for all SFDC to PEGA flows
* 
* @author
*
* @change HCL 05/27/2016 Added new fields to PEGA interface
* @Updated by : Issac Pal C 13/02/2019 - Updated the GCQQRateSheets according to new Rates Structure receiving from PEGA.
*/

global with sharing class P2EwPegaService {
    public class QQProposal {
        public String CaseID; // for Re-Rate
        public String RelatedIMCaseID; // Added by Murali for Re-IMPL Process
        //public String SFDCCaseID; // for IMPL Calls alone
        public QQQAccount Account;
        public QQOpportunity Opportunity;
        public QQPlans[] Plans;
        public QQContacts[] Contacts;
        public P2EwTermTransferPegaService.TermAndTransferNode[] TermAndTransfer;//added for T&T Requirement
        public QQProposal(QQQAccount Account, QQOpportunity Opportunity, QQPlans[] Plans){
            this.Account = Account;
            this.Opportunity = Opportunity;
            this.Plans = Plans;
        }
        public QQProposal(QQQAccount Account, QQOpportunity Opportunity, QQPlans[] Plans, QQContacts[] Contacts){
            this.Account = Account;
            this.Opportunity = Opportunity;
            this.Plans = Plans;
            this.Contacts = Contacts;
        }
    }
    public class TermAndTransferNode{
        Public String TermTransferType;
        Public String TermTransferSubType;
        Public String TermingGroup;        
        Public String TermingDivision;
        Public String NewDivBenefits;
        Public String NewDivNames;
        Public String NewDivNumbers;        
        Public String IMNotes;
        Public String Approvals;
        Public String BillContactMail;
        Public String BillContactName;
        Public String BillContactPhone;
        Public String BillRollUpId;
        Public String DivContactMail;
        Public String DivContactName;
        Public String DivContactPhone;
        Public String DivType;        
        Public Date EnrollEffDate;
        Public Date DivEffTermDate;
        Public Date GrpEffTermDate;
        Public Date NewDivsEffDate;
        Public String EMAOBRInfo;
        Public String EnrollTransferTo;
        Public String EnrollTransferType;
        public Boolean AddADivsion;
        public SourceAcctInfoNode[] SourceAcctInfo;
    }//T&T Req End
    
    public class SourceAcctInfoNode {
        public Boolean TenPerEnrollIncreaseReduction;
        public String AccountID;
        public String SitusState;
        public String SICCode;  
        public String ParentName;    
        public String ParentAccountID;  
        public Integer NumberOfEmployees;   
        public TermNAIC[] NAICList;
        public Boolean BidSpecification;
        public TermAddressList[] AddressList;
        public String AccountNumber;
        public String AccountName; 
        public TermAccountManager AccountManager;
        public TermAccountExecutive AccountExecutive;
        //public TermOpportunity Opportunity;
        public GroupInfo[] GroupInfo;
    }
    public class TermNAIC{
        public String NAICCode;
        public String NAICDesc;
        public TermNAIC(String NAICCode, String NAICDesc){
            this.NAICCode = NAICCode;
            this.NAICDesc = NAICDesc;
        }
    }
    public class TermAddressList {
        public String Zip;
        public String State;
        public String pyEmailAddress; 
        public String PhoneNumber;
        public String Fax;
        public String City; 
        public String AddressLine2;
        public String AddressLine1; 
        public String AddressDetails;  
        public String AddressType;
        public Boolean IsPrimary;
        public TermAddressList(String AddressDetails, 
                               String AddressLine1, 
                               String AddressLine2, 
                               String City, 
                               String Fax, 
                               String PhoneNumber, 
                               String pyEmailAddress, 
                               String State,
                               String Zip,
                               String AddressType,
                               Boolean IsPrimary)
        {
            this.AddressDetails = AddressDetails;
            this.AddressLine1 = AddressLine1;
            this.AddressLine2 = AddressLine2;
            this.City = City;
            this.Fax = Fax;
            this.PhoneNumber = PhoneNumber;
            this.pyEmailAddress = pyEmailAddress;
            this.State = State;
            this.Zip = Zip;
            this.AddressType = AddressType;
            this.IsPrimary = IsPrimary;
        }
    }
    public class GroupInfo {
        public String SoldPlanDesign;
        public Boolean IsGroupTerminate;
        public String UnderwrittenBy;
        public String GroupType;
        public String SubGroupType;
        public String GroupNumber;  
        public String GroupName;
        public String ContractTermTo; 
        public String ContractTermFrom;
        //public String ContractEndDate;
        public String RenewalDate;
        public String RenewalClause;
        Public Integer ContractTerm;
        Public String ContractId;
        Public DivisionInfo[] DivisionInfo;   
    }
    public Class DivisionInfo{
        public String DivisionNumber;
        public String DivisionName;
        public string DivisionId; //added by Raajalaxmee
    }
    
    public class TermAccountExecutive {
        public String Name;   
        public String pyEmailAddress;   
        public String ExternalId;
        public String pyUserIdentifier;
        public TermAccountExecutive(String Name, String pyEmailAddress){
            this.Name = Name;
            this.pyEmailAddress = pyEmailAddress;
        }
    }    
    public class TermAccountManager {
        public String Name;   
        public String pyEmailAddress;
        public String ExternalId;
        public String pyUserIdentifier;
        public TermAccountManager(String Name, String pyEmailAddress){
            this.Name = Name;
            this.pyEmailAddress = pyEmailAddress;
        }
    }
    public class QQDivisionInfo { //added for T&T Requirement
        public String DivisionNumber;
        public String DivisionName;
        public String DivisionId;
    }//T&T Req End
    public class QQQAccount {
        public Boolean TenPerEnrollIncreaseReduction;
        public Integer NumberOfEmployees;  
        public Integer NumberOfEligibleEmployees; 
        public String SICCode;  
        public String AccountID;
        public QQNAIC[] NAICList;
        public QQAccountExecutive AccountExecutive;
        public QQAccountManager AccountManager;
        public QQAddressList[] AddressList;
        public QQGroupInfo[] GroupInfo;
        public String AccountName;
        public String AccountNumber;
        public String SitusState;   
        public String ParentName;  //Added for PC-12835
        public String ParentAccountID; //Added for PC-12835
        
        //RFP
        public Boolean BidSpecification;
        //Iteration 3
        public String Affiliation;
        public String AccountType;
        public String SubType;
        public String DBA;
        public String SalesGrade;
        //Employees and Enrollees
        public Integer TotalEmployees;
        public String CompanyStatus;
        public String Type;
        public Boolean IsPool;
        public Boolean IsExchange;
        public Boolean IsStateExchange;
        public Boolean IsMedicalPartner;
        
        //Prior Delta Group for prospect
        public Boolean PriorDeltaGroup;  
    }
    public class QQGroupInfo {
        public String GroupNumber;
        public String GroupName;
        public String GroupType;
        public String SubGroupType;
        public String ContractTermFrom;
        public String ContractTermTo;
        public String ContractEndDate;
        public String RenewalDate;
        //public String UWCompany;
        //public String RenewalMonth;
        public String RenewalClause;
        //public String RenewalDate;
        public Integer ContractTerm;
        public String UnderwrittenBy;
        public Boolean SoldPlanDesign;
        public String ContractId;
        public Boolean IsGroupTerminate;//PC-13770
        public Boolean TermAndTransfer;//T&T Req
        public Boolean TenPerEnrollIncreaseReduction;//T&T Req
        public QQDivisionInfo[] DivisionInfo; //T&T Req
    }
    
    public class QQContactInfo {
        public String ContactName;
        public String ContactType;
        public String MailingStreet;
        public String MailingCity;
        public String MailingState;
        public String MailingPostalCode;
        public String MailingCountry;
        public String MailingCounty;
        public String Fax; 
        public String PhoneNumber;  
        public String pyEmailAddress;
        public String ContactRole;
        public Boolean IsPrimary;
    }
    
    public class QQAccount {
        public Integer NumberOfEmployees;
        public Integer NumberOfEligibleEmployees;
        public String SICCode;  
        public String AccountID;
        public QQNAIC[] NAICList;
        public QQGroupInfo[] GroupInfo;
        public QQAccountExecutive AccountExecutive;
        public QQAccountManager[] AccountManager;
        public QQAddressList[] AddressList;
        public String AccountName;
        public String AccountNumber;
        public String SitusState;  
        public String ParentName;   //Added for PC-12835 
        public String ParentAccountID; //Added for PC-12835 
        
        //RFP
        public Boolean BidSpecification;
        //Iteration 3
        public String Affiliation;
        public String AccountType;
        public String SubType;
        public String DBA;
        public String SalesGrade;
        public String CompanyStatus;
        public String Type;
        //Prior Delta Group for prospect
        public Boolean PriorDeltaGroup;  
    }
    public class QQNAIC{
        public String NAICCode;
        public String NAICDesc;
        public QQNAIC(String NAICCode, String NAICDesc){
            this.NAICCode = NAICCode;
            this.NAICDesc = NAICDesc;
        }
    }
    public class QQAccountExecutive {
        public String Name;   
        public String pyEmailAddress;   
        //Iteration 3
        public String ExternalID;
        public String pyUserIdentifier;
        public QQAccountExecutive(String Name, String pyEmailAddress){
            this.Name = Name;
            this.pyEmailAddress = pyEmailAddress;
        }
    }
    public class QQAccountManager {
        public String Name;   
        public String pyEmailAddress;
        //Iteration 3
        public String ExternalID;
        public String pyUserIdentifier;
        public QQAccountManager(String Name, String pyEmailAddress){
            this.Name = Name;
            this.pyEmailAddress = pyEmailAddress;
        }
    }
    public class QQAddressList {
        public String AddressDetails;  
        public String AddressLine1; 
        public String AddressLine2; 
        public String City; 
        public String Fax; 
        public String PhoneNumber;  
        public String pyEmailAddress;   
        public String State;    
        public String Zip;
        public String Country;
        //Iteration 3
        public String AddressType;
        public Boolean IsPrimary;
        public QQAddressList(String AddressDetails, 
                             String AddressLine1, 
                             String AddressLine2, 
                             String City, 
                             String Fax, 
                             String PhoneNumber, 
                             String pyEmailAddress, 
                             String State,
                             String Zip,
                             String Country,
                             String AddressType,
                             Boolean IsPrimary){
                                 this.AddressDetails = AddressDetails;
                                 this.AddressLine1 = AddressLine1;
                                 this.AddressLine2 = AddressLine2;
                                 this.City = City;
                                 this.Fax = Fax;
                                 this.PhoneNumber = PhoneNumber;
                                 this.pyEmailAddress = pyEmailAddress;
                                 this.State = State;
                                 this.Zip = Zip;
                                 this.Country = Country;
                                 this.AddressType = AddressType;
                                 this.IsPrimary = IsPrimary;
                             }
    }
    public class QQGroup{
        public String GroupNumber;
        //public String GroupType;
        //public String SubGroupType;
        public String ContractTermFrom;
        public String ContractTermTo;
        //public String RenewalMonth;
        public String RenewalClause;
        public Integer NoOfEnrollees;
        public String RenewalDate;
        public Integer ContractTerm;
        public String UnderwrittenBy;
        //public Boolean SoldPlanDesign;
    }
    public class QQSFDCCase {
        public String CaseID;
        
    }
    
    public class QQOpportunity {
        //Notes
        public QQSFDCCase SFDCCase;
        public String SalesNotes;
        public QQNotes[] SalesNotesList;
        public Date effectiveDate;
        //public String UWNotes;//commented for UWNotes
        public QQUWNotes[] UWNotesList;//added for UWNotes
        public String Notes;
        public Decimal Amount;   
        public String OpportunityID;
        public String QuoteID;    
        public String RateChangeType; 
        public string OpportunityType;   
        //RFP
        //public Boolean HasClaimsExperience; //Added for 2-way communication
        public String DueDateClaimsExperience;
        public String ClaimsExperienceNotes; 
        public Boolean HasCostSavingPG;
        public String DueDateCostSavingPG;
        public String CostSavingPGNotes;
        public Boolean HasFeeAnalysis;
        public String DueDateFeeAnalysis;
        public String FeeAnalysisNotes;
        public Boolean HasGeoAccess;
        public String DueDateGeoAccess;
        public String GeoAccessNotes;
        public Boolean HasPG;
        public String DueDatePG;
        public String PGNotes;
        public Boolean HasRecruitmentPG;
        public String DueDateRecruitmentPG;
        public String RecruitmentPGNotes;
        public Boolean HasDisruptionAnalysis;
        public String DueDateDisruptionAnalysis;
        public String  DisruptionAnalysisNotes;
        public Boolean HasDeviationReview;
        public String DueDateDeviationReview;
        public String  DeviationReviewNotes;
        public Boolean HasRepricing;
        public String DueDateRepricing;
        public String RepricingNotes;
        //public Boolean HasManualRates; // removed as part of Iteration 3
        
        public Boolean HasNetworkDiscount;
        public String DueDateNetworkDiscount;
        public String NetworkDiscountNotes;
        
        public Boolean ProviderUtilization;
        public String DueDateProviderUtilization;
        public String  ProviderUtilizationNotes;
        
        public Boolean ProviderCountsNWComp;
        public String DueDateProviderCountsNWComp;
        public String  ProviderCountsNWCompNotes;
        
        public Boolean NetworkGrowthandTurnover;
        public String DueDateNetworkGrowthandTurnover;
        public String  NetworkGrowthandTurnoverNotes;
        
        public Boolean AdhocProviderReport;
        public String DueDateAdhocProviderReport;
        public String  AdhocProviderReportNotes;
        
        public Boolean FinancialExperience;
        public String DueDateFinancialExperience;
        public String  FinancialExperienceNotes;
        
        public Boolean NetworkUtilization;
        public String DueDateNetworkUtilization;
        public String  NetworkUtilizationNotes;
        
        public Boolean MaximumReport;
        public String DueDateMaximumReport;
        public String  MaximumReportNotes;
        
        public Boolean ExecutiveSummary;
        public String DueDateExecutiveSummary;
        public String  ExecutiveSummaryNotes;
        /*
        public Boolean DHMOFinancial;
        public String DueDateDHMOFinancial;
        public String  DHMOFinancialNotes;
        
        public Boolean DHMOUtilization;
        public String DueDateDHMOUtilization;
        public String  DHMOUtilizationNotes;
        */
        
        //Added for 2-way communication
        public Boolean DHMOUtilizationFinancial;
        public String DHMOUtilizationFinancialDueDate;
        public String  DHMOUtilizationFinancialNotes;
        
        public Boolean StateFederalPrograms;
        public String StateFederalProgramsDueDate;
        public String  StateFederalProgramsNotes;
        
        public Boolean D2CAdhocRequest;
        public String D2CAdhocRequestDueDate;
        public String  D2CAdhocRequestNotes;
        //Till Here
        
        public Boolean ActuarialAdhocReport;
        public String DueDateActuarialAdhocReport;
        public String  ActuarialAdhocReportNotes;
        
        public Boolean IsAutoRenewal;
        
        //****PC-15314 - Added below flag
        public Boolean IsSpecialAutoRenewal;
        
        public Boolean HasDHMOPlanComparsion;
        public String DHMOPlanComparsionDate;
        public String DHMOPlanComparsionNotes;
        
        /*public Boolean HasNetworkSize;
public String NetworkSizeNotes;
public String DueDateNetworkSize;*/
        
        //public Boolean HasScorecard;
        //public String DueDateScorecard;
        
        public Boolean HasQuestionnaire;
        public String DueDateQuestionnaire;
        public String QuestionnaireNotes;
        
        public Boolean HasForm5500;     
        public String DueDateForm5500;      
        public String Form5500Notes;                
        public String GroupNumber;      
        public String DivisionNumber;       
        public String Form5500StartDate;        
        public String Form5500EndDate;      
        //public String ContractStartDate;        
        //public String ContractEndDate;
        //public Boolean HasSPD;
        //public String DueDateSPD;
        //public String  SPDNotes;
        
        public String PGType;
        //public String ScoreCardType;
        public QQAgeDistribution AgeDistribution;
        public QQBroker[] Broker;
        public QQCensus[] Census;
        //Iteration 3
        public String DueDate;
        public String DateReqByGroup;
        public String DeliveryType;
        public String UWDueDate;    // Iteration 7.12
        public String DueDateReason;// Iteration 7.12
        public String EventGroupName;
        public String StrategicInfo;
        public QQGroup GroupInfo;
        
        //
        public QQEarlyRenewalSurvey Survey;
        
        public String RFPType;
        //Employees and Enrollees
        public Decimal EligiblePrimaryEnrollees;
        public Integer TotalPrimaryEnrollees;
        public Integer CurrentFFSSubscribers;  //Added for Lives Change
        public Integer CurrentDHMOSubscribers; //Added for Lives Change
        public String NoteForOtherCredit;
        //iteration 7
        /*public String OtherCredit;
public String ImplementationCredit;
public String CommunicationCredit;
public String AuditCredit;
public String FrequencyCredit;
public String CreditType;*/
        /*
public String TypeOfCredits;
public String AuditCredits;
public String AuditCreditsFrequency;
public String AuditCreditsType;
public String CommunicationCredits;
public String CommunicationCreditsFrequency;
public String CommunicationCreditsType;
public String ImplementationCredits;
public String ImplementationCreditsFrequency;
public String ImplementationCreditsType;
public String OtherCredits;
public String OtherCreditsFrequency;
public String OtherCreditsType;
*/
        public QQCreditDetails[] CreditDetails;
        public Boolean CreditsCheck;
        public QQRequestedGroupNums[] RequestedGroupNums;
        public String Priority1;
        public String Priority2;
        public String Priority3;
        public String Priority4;
        public String Priority5;
        public Boolean PriorDentalCoverage;
        
        
        
        
        
        //added for PC-11577
        
        public Boolean DisruptionPPOAndPremier;
        public Boolean DisruptionDeltaCare;
        
        
        public Boolean  GeoPPO;
        public Boolean  GeoPremier;
        public Boolean  GeoPPOAndPremier;
        public Boolean GeoDeltaCare;
        
        public Boolean UrbanSuburbanRural;
        
        public String OtherNotes;
        public String CensusPasswordifApplicable;
        
        //  public Boolean State; 
        public Boolean CBSA; 
        public Boolean County; 
        public Boolean City; 
        public Boolean Zip; 
        
        public Boolean FeasibilityReview;
        public String DueDateFeasibilityReview;
        public String FeasibilityReviewExpectedNotes;  
        
        
        public Boolean AllEmployees;
        public Boolean RetiredOnly; 
        public Boolean ActiveOnly; 
        public String  OtherTypeofFilter;
        public Boolean GDSPCombined; 
        public Boolean GDOnly;
        public Boolean SPOnly;
        
        public string  Urban2Providers;
        public string  Rural2Providers;
        public string  Suburban2Providers;      
        
        public boolean GDandSP10Miles;
        public boolean GDandSP8Miles;
        public boolean GDandSP15Miles;
        public boolean GDSP10Milesand1SP15Miles;
        public string  GDSP10MilesSpecialtyType;
        public string  GDSP8MilesSpecialtyType;
        public string  GDSP15MilesSpecialtyType;
        public string  GD10Miles1SP15MilesSpecialtyType;   
        
        public string  UrbanSpecialtyType;
        public string  RuralSpecialtyType;
        public string  SuburbanSpecialtyType;
        
        public string CurrentCarrier;
        public string CompetitorCarrier;
        public string CarrierRelatedNotes;
        public string CompetitorRelatedNotes;  
        public string  DATemplateSelection; 
        
        public string  GeoTemplateSelection;
        public String  GeoTemplateNotes;
        public String DATemplateNotes; 
        
        
        
    }
    
    public class QQRequestedGroupNums{
        public String GroupNumber;
    }
    
    public class QQEarlyRenewalSurvey{
        public String ReasonForEarlyRenewal;
        public String ReasonForRequest;
        public Date DueDate;
        public String AlternativesNeeded;
        public String UpdateRenewalClause;
        public String OpenService;
        public String SensitiveIssues;
        public String DeltaPositionedNeutralOrCompetitive;
        public String AcquisitionsOrNewGroupGrowing;
        public String CompetitiveConsiderations;
    }
    
    public class QQAgeDistribution 
    {
        public Integer AgeBandHigh; 
        public Integer AgeBandLow;
        public Integer CustomAgeDistribution;  
        public Integer StandardAgeDistribution; 
        //Iteration 3
        public String State;
        public QQAgeDistribution (
            Integer AgeBandHigh,
            Integer AgeBandLow,
            Integer CustomAgeDistribution,
            Integer StandardAgeDistribution,
            String State)
        {
            this.AgeBandHigh = AgeBandHigh;
            this.AgeBandLow= AgeBandLow;
            this.CustomAgeDistribution = CustomAgeDistribution;
            this.StandardAgeDistribution = StandardAgeDistribution;
            this.State = State;
        }
    }
    public class QQBroker {
        public String BrokerID;
        public String BrokerName;
        public QQCommission Commission;
        public QQAddressList Address;
        //Iteration 3
        public String Type;
        public String ProducerRole;
        public Boolean NewProducerOrBroker;
        public QQBroker(){}
        public QQBroker(String BrokerId, String BrokerName, QQCommission Commission, QQAddressList Address){
            this.BrokerId = BrokerId;
            this.BrokerName = BrokerName;
            this.Commission = Commission;
            this.Address= Address;
        }
    }
    public class QQCommission{
        public String CommissionPercentOrDollor;
        public String CommissionReqPercentOrDollar; //Added for 2-way communication
        public Decimal CommissionRequested;
        public Decimal CurrentCommission;
        public Decimal AdditionalCommission;
        
        public QQCommission(String CurrentCommPercentOrDollor, String CommissionReqPercentOrDollar, Decimal CommissionRequested,Decimal CurrentCommission,Decimal AdditionalCommission){
            this.CommissionRequested = CommissionRequested;
            this.CurrentCommission = CurrentCommission;
            this.CommissionPercentOrDollor = CurrentCommPercentOrDollor;
            this.CommissionReqPercentOrDollar = CommissionReqPercentOrDollar;
            this.AdditionalCommission = AdditionalCommission;
        }
    }
    public class QQAddress {
        public String City; 
        public String State;    
        //public String StreetAddress;
        //Iteration 3
        public String EmailId;
        public String PhoneNumber;
        public String Fax;
        public String AddressLine2;
        public String AddressLine1;
        public String AddressDetails;
        public QQAddress (String City, 
                          String State)
        {
            this.City= City;
            this.State= State;
        }
    }
    public class QQCensus 
    {
        public Integer Enrollee; 
        public String State;    
        public String Zip;
        public QQCensus (Integer Enrollee, 
                         String State,
                         String Zip)
        {
            this.Enrollee = Enrollee;
            this.State = State;
            this.Zip = Zip;
        }
    }
    public class QQAdminRates
    {
        public String AdminAnalysis;
        public Decimal PercentofClaims;
        public Decimal PEPMRate;     
    }
    public class QQSpanRates
    {
        public double RateMultiplier; 
        public string BillingSpanStartDate;
        public string BillingSpanEndDate;
        public QQAdminComponent[] AdminComponents;
        public QQRates[] Rates;
    }
    public class QQAdminComponent
    {
        public string AdminComponentType;
        public string AdminComponentContri;
        public string ContribePercentOrDollar;
    }
    public class QQRates
    {
        public decimal AdminComponent;   
        //public Decimal Rate;
        public string BilledRate;
        public String ContractTypeCode;
        // public Decimal CurrMaxLiabilityRate;
        // public Decimal CurrentBilledRate;
        public Decimal CurrentRate;         
        public Decimal CurrentSubsidyRate;
        public Decimal CurrentTotalRate;
        public Decimal ProposedSubsidyRate;
        public Decimal ProposedBilledRate;
        public Decimal ProposedTotalRates;     
        public Decimal ProposedMaxLiabilityRate;
        public Decimal ProposedRate;    
        public decimal PurePremium;             
        public Decimal RenewalRate;
        public Decimal RequiredRate;
        public Decimal RqdMaxLiabilityRate;         
        //  public String States;
        // public String TierType;
        public Integer TotalCensus;
        //   public Integer TotalCensusRate;    
    }
    public class QQGenerateRates
    {
        public String Rate1;
        public String Rate2;
        public String Rate3;
        public String Rate4;
        public String Rate5;
        public String ContractTypeCode;
        public String RateType;
        //public String CustomDate;
        public String RateMultiplier;
        //  public String TierDesc;
        //  public String TierSubType;
    }
    public class QQOriginalRates
    {
        public String ContractTypeCode;
        public String TierType;
        public Integer TotalCensus;
        public Integer TotalCensusRate;
        public Decimal CurrMaxLiabilityRate;
        public Decimal CurrentBilledRate;
        public Decimal CurrentRate;
        public Decimal CurrentSubsidyRate;
        public Decimal CurrentTotalRate;
        public Decimal ProposedSubsidyRate;
        public Decimal ProposedBilledRate;
        public Decimal ProposedTotalRates;
        public Decimal ProposedRate;
        //   public Decimal ProposedCurrent;
        //   Public Decimal ProposedSubsidyTotalRates;
        //   Public Decimal ProposedMaximumLiabiliityChange;
        public Decimal RenewalRate;
        public Decimal RequiredRate;
        public Decimal RqdMaxLiabilityRate;
        //   public Decimal ProposedMaximumLiabilityRate;
        public Decimal ProposedMaxLiabilityRate;
        public String States;
    }
    public class QQRateSheets{
        public QQAdminRates[] AdminRates;      // Existing not in New
        public ASCFeeBreakdown[] ASCFeeBreakdown; // Present in both
        public QQSpanRates[] Spans; //Only in New   
        public QQGenerateRates[] GenerateRates; // Existing not in New
        public QQSegments[] Segments; // Existing present in Both   
        public String AdminRateType;   // Existing present in Both
        public QQOriginalRates[] OriginalRates; // Existing not in new                     
        public string AppliedNetworks; // Existing present in both      
        public Boolean  CustomDate; // Existing present in Both
        public String ContribePercentOrDollar;  //Only in New    
        public Decimal CurEmployerContriForDependent;     //Only in New    
        public Decimal CurEmployerContriForEmployee;    //Only in New    
        public String CustomerSharedSavingsPercentage;   //Only in New     
        public String DeltaRetainedSavings;  //Only in New   
        public Decimal CurrCumulativeStabilization; // Existing present Not in New
        public string EndDate;      // Existing present in Both
        public Decimal EqualizedDepositFlatRateCharge;   //Only in New   
        public Decimal InitialPrefundAmount;  // Existing present in Both
        public String MonthlyDeposit; // Existing present in Both
        public String PremiumHoliday; // Existing present in Both
        public Decimal PEPMAdminFee;   //Only in New   
        public Decimal PercentageofClaims;      //Only in New   
        public Decimal ProjectedStabilization; // Existing present Not in New
        public Decimal ProposedChangeTotalRates; // Existing present in Both
        public Decimal ProposedMaxLiabilityChange; // Existing present in Both
        public Decimal ProposedRenewalChange; // Existing present in Both
        Public Decimal ProposedSubsidyChange;   // Existing present in Both        
        public Decimal RequiredRenewalChange; // Existing present in Both 
        public Decimal RequiredChangeTotalRates; // Existing present in Both 
        public Decimal RequiredMaxLiabilityChange; // Existing present in Both   
        public Decimal ProposedCurrent; // Existing present Not in New        
        public String RateType; // Existing present in Both 
        public Decimal RateMultiplier1; // Existing present in Both 
        public Decimal RateMultiplier2;  // Existing present in Both      
        public Decimal RateMultiplier3;  // Existing present in Both 
        public Decimal RateMultiplier4;  // Existing present in Both     
        public Decimal RequiredCurrent; // Existing present Not in New
        public String RequestQuote; // Existing present Not in New
        public String ResponseQuote;  // Existing present Not in New 
        public String RateSheetId; // Existing present Not in New  
        public string RepricingBasis; // Existing present in Both 
        public string RepricingLevel; // Existing present in Both 
        public String RatesheetType;    //Only in New        
        public string StartDate; // Existing present in Both 
        public String State; // Existing present in Both 
        public boolean StandardPricing;  //Only in New        
        public String StopLossCorridor; // Existing present in Both 
        public Decimal SubsidyAsOfTotalRates; // Existing present in Both         
        public string TierStructureCode; // Existing present in Both         
        Public Decimal Total; // Existing present in Both   
        public String TotalPrefundAmount; // Existing present in Both                               
        public String Type;    // Existing present Not in New  
    }
    
    
    //author : kiran Patel
    //changes : 12-2-19 : change based on new structure
    public class ASCFeeBreakdown
    {
        // public Integer ASCFeeType;
        Public String ComponentType;
        public String CurrentASCFee; //
        public string ComponentBasis;
        public String RenewalASCFee; //
        public string RenewalComponentBasis;
        public String ProposedASCFee; //
        public string ProposedComponentBasis;
    }
   /* public class GCQQRateSheets
    {
        public QQAdminRates[] AdminRates; 
        public ASCFeeBreakdown[] ASCFeeBreakdown;
        public QQSpanRates[] Spans; 
        public QQSegments[] Segments;      
        public String AdminRateType;  
        public string AppliedNetworks;         
        public Boolean  CustomDate;        
        public String ContribePercentOrDollar;
        public Decimal CurEmployerContriForDependent;   
        public Decimal CurEmployerContriForEmployee;  
        public String CustomerSharedSavingsPercentage;     
        public String DeltaRetainedSavings;
        public String EndDate; // Changed to String     
        public Decimal EqualizedDepositFlatRateCharge;  
        public String InitialPrefundAmount; 
        public String MonthlyDeposit;    
        public String PremiumHoliday;
        public Decimal PEPMAdminFee;
        public Decimal PercentageofClaims;     
        public Decimal ProposedChangeTotalRates;
        public Decimal ProposedMaxLiabilityChange;
        public Decimal ProposedRenewalChange;
        Public Decimal ProposedSubsidyChange;
        public Decimal RequiredRenewalChange;
        public Decimal RequiredChangeTotalRates;
        public Decimal RequiredMaxLiabilityChange;        
        public String RateType;      
        public Decimal RateMultiplier1;
        public Decimal RateMultiplier2;     
        public Decimal RateMultiplier3;
        public Decimal RateMultiplier4;  
        public string RepricingBasis;
        public string RepricingLevel;
        public String RatesheetType;        
        public String StartDate;
        public String State;
        public boolean StandardPricing;
        public String StopLossCorridor;      
        public Decimal SubsidyAsOfTotalRates;
        public String TierStructureCode;
        public Decimal Total;
        public String TotalPrefundAmount;                               
    }*/
    /**GuaranteedRates
public class QQGauranteedRates
{
Public QQcode[] code;
}
public class QQcode
{
public String Type;
public String Code;
public QQDateRates[] DateRates;
}
public class QQDateRates
{
public String Dates;
public String Rates;
}
*******/
    
    public class QQContacts
    {
        public String ContactID;
        public String ContactType;
        public String LastName;
        public String FirstName;
        public String CompanyName;
        public String TitleName;
        //public String SelfServiceAccess;
        //public String AccessRole;
        public String PhoneNumber; 
        public String Email;
        public String Fax;
        public QQAddressesList[] AddressesList;
    }
    
    public class QQAddressesList
    {
        public String Type;
        public String AddressLine1;
        public String AddressLine2;
        public String StreetAddress;
        public String City;
        public String State;
        public String Zip;
        public String County;
        public String Country;
        public QQAddressesList(){
        }
        public QQAddressesList(String Type,
                               String AddressLine1,
                               String AddressLine2,
                               String StreetAddress,
                               String City,
                               String State,
                               String Zip,
                               String County,
                               String Country)
        {
            this.Type = Type;
            this.AddressLine1 = AddressLine1;
            this.AddressLine2 = AddressLine2;
            this.StreetAddress = StreetAddress;
            this.City = City;
            this.State = State;
            this.Zip = Zip;
            this.County = County;
            this.Country = Country;
        }
    }
    
    global class QQPlans 
    {
        public String QuoteID;
        public Boolean FlexibleDualChoice;
        public Boolean hasRatesChanged;
        //  public GCQQRateSheets[] GCRateSheets; 
        public QQRateSheets[] RateSheets;
        //public String RenewalDate;
        public String Entity;
        public Boolean IsCurrentPlan;
        public String ProductDescription;
        public QQBroker[] Broker;
        public Boolean Buyup;
        public Decimal Commission; 
        public String ContractStartDate;
        public String ContractType;
        public String ContribePercentOrDollar;
        public Decimal CurEmployerContriForDependent;   
        public Decimal CurEmployerContriForEmployee;   
        public Integer CurrentPrimaryEnrolee;   
        public Integer DependentAge;
        public Boolean DualChoice;
        public String DHMOPlan;
        //public Decimal EligibleEmployees;  
        public Decimal EmployerContriDependent;
        public Decimal EmployerContriSingle;
        //public Boolean HasQuestionnaire;
        //public Boolean HasSPD;
        public Boolean Hybrid;
        public String OONReimbursement; 
        public String PlanID;  
        public String Product2ID; 
        public String PlanName;
        public Decimal PreviousCommission;  
        public String ProductName;  
        public String GroupPlanName;   // Added by Murali for PC-15498 on 9/25/17
        public String ProgramType;
        public String PPOAlwSchedule;
        public String PMRAlwSchedule;
        public String NPAlwSchedule;        
        public QQProduct Product;
        public QQSegments[] Segments;
        public QQTierDetails[] TierDetails;
        // RFP
        public String ContractEndDate;
        public String PaymentFrequency;
        public String PaymentFrequencyComments;
        public String ContractTurnOver;
        public String ContractLength;
        public String ContractLengthComments;
        public QQEligibility Eligibility;
        //public String DueDate;
        //Iteration 3
        public String BenefitDesignComments;
        public String CompetitorsBidding;
        public Boolean Deviation;
        public String EffectiveDate;
        public Boolean EOC;
        public Boolean IDCardType;
        public Boolean MatchforQuote;
        public String NewHireEligibilityPeriod;
        public String EligibleParticipantsComments;
        public String ProposedContrComments;
        public Boolean Section125Ind;
        public Integer StudentAge;
        public String StrategicInfo;
        public QQUWQuestionnaire UWQuestionnaire;
        public QQCarrier[] Carriers;
        public QQBenefitPackages[] BenefitPackages;    // Added by Murali for PC-15498 on 9/25/17
        // for Renewal & Change actions
        
        public Boolean CurrentPlan;
        public Boolean Discontinued;
        /*public Boolean ChangeInBenefit;
public Boolean ChangeInRate;
public Boolean ChangeInEligibility;
*/
        // marked in RED
        public String BenefitPackageID;
        public String FinanceID;
        public String EligibilityID;
        public String NewProvider;
        // 
        /*
public Boolean IsClonedByUW;
public String UWClonedProduct2ID;
public String UWClonedPlanID;
*/
        public String ClonedPlanID;
        // 
        public String GroupNumber;
        public String GroupName;
        public String Action;
        
        public Boolean COBRA;  // should be changed to COBRA
        public String Notes;
        // iteration 7
        public Boolean PartialZip;
        public Boolean FullZip;
        public String ImplementationNotes;
        public String BenefitNotes;
        public String SalesNotes; //Notes
        public QQNotes[] SalesNotesList;
        public String UWNotes;
        
        // Change
        public String Type;
        public String ChangeType;
        public String RenewalContact;
        public Date RenewalDate;
        public Date BenefitChangeEffectiveDate;
        
        public Boolean TOA;
        public String TOAType;
        public String RequestedContractedLength;
        public Boolean IsOfferedPlan;
        public Boolean RateUpdated;
        public Boolean OriginalPlan;
        public String OSRPlanID;
        //public Boolean OSRPlan;  //13674
        public Boolean OSRPlanSFDC;  //PC-15155
        /****HCL::START Added new fields to PEGA interface****/
        public String IdCard;
        public Boolean SmileWay;
        public String Pricing;
        public String Brand;
        public String PRCaseId;
        public String DeltaRetainedSavings;
        /****HCL::END****/ 
        
        public Decimal ApproveCommission;           //Added for 2-way communication
        public String ApproveCommissionType;        //Added for 2-way communication
        //public Boolean HasClaimsExperience;//added by geetha for JIRA 5511
        
    }
    /*public class QQRateSheets {
public QQOriginalRates[] OriginalRates;
}*/
    /*public class QQOriginalRates {
public String CurrentRate;  
public String ManualRate;  
public String TierName; 
public String ContractTypeCode; 

public Decimal TotalCensus;
public Decimal RenewalCurrentChange;
public Decimal ManualCurrentChange;
public Decimal ExperienceCurrentChange;
public String ImplementationNotes;
public String BenefitNotes;
public Decimal CarRates;
public Decimal IncrementalRates;
public String ProposedNetAdmin;
public String ProposedCarsRatio;
public String PrpsdIncrAdmRatio;
public String Commission;
public String TotalProposedAdmin;        
}        */
    public class QQCarrier {
        public String CarrierType;
        public String CarrierName;
        public Decimal Length;
        public QQCarrier(String CarrierType, String CarrierName, Decimal Length){
            this.CarrierType = CarrierType;
            this.CarrierName = CarrierName;
            this.Length = Length;
        }
    }
    
    /*** PC-15498 (Missing BP Solution) Start ***/
    public class QQBenefitPackages {
        public String BPID;
        public QQBenefitPackages(String BPID){
            this.BPID = BPID;
        }
    }
    /*** PC-15498 End ***/
    
    public class QQCreditDetails {
        public String CreditID;       //Added for 2-way communication
        public String Type;
        public String PEPMorDollar;
        public String Amount; //Dec
        public String GrantedAmount;
        public String Frequency;
        public String SalesNotes;    //Added for 2-way communication
        public String UWNotes;       //Added for 2-way communication
        
        public QQCreditDetails(String cID,String Type,String PEPMorDollar,String Amount,String GrantedAmount,String Frequency,String SalesNotes,String UWNotes) {
            this.CreditID = cID;
            this.Type = Type;
            this.PEPMorDollar = PEPMorDollar;
            this.Amount = Amount;
            this.GrantedAmount = GrantedAmount;
            this.Frequency = Frequency;
            this.SalesNotes = SalesNotes;
            this.UWNotes = UWNotes;
        }
    }
    public class QQUWQuestionnaire {
        public QQFeatureDetails FeatureDetails;
        public QQOtherFeatures OtherFeatures;
    }
    public class QQFeatureDetails {
        public Boolean CheckAdditionalTraining;
        public Boolean CheckBenefitConfiguration;
        public Boolean CheckCodeAudit;
        public Boolean CheckIncentiveRule;
        public Boolean CheckPricingRule;
        public String TrainingNotes;
        public QQDescNotes[] NewBenefitConfiguration;
        public QQDescNotes[] NewPricingRule;
        public QQDescNotes[] NewCodeAudit;
        public QQDescNotes[] NewIncentiveRule;
    }
    public class QQOtherFeatures {
        public Boolean CheckMTVFeature;
        public Boolean CheckNewReport;
        public Boolean CheckNonStandardIDCardFeature;
        public Boolean CheckNonStandardWebFeature;
        public Boolean CheckRMBHcentiveFeature;
        public String TrainingNotes;
        public QQDescNotes[] NewReportFeatureUWquestionnaire  ;
        public QQDescNotes[] NewMTVFeature;
        public QQDescNotes[] NewRMB;
        public QQDescNotes[] NonStandardWebFeature;
        public QQDescNotes[] NonStandardIDCardFeature;
        public QQDescNotes[] NewReport;
    }
    public class QQDescNotes {
        public String FeatureDescription;
        public String FeatureNotes;
        public String FeatureMTVType;
        public String pxCreateDateTime;
        public String pxCreateOpName;
        public String pxCreateSystemID;
        public String pxCreateOperator;
    }
    public class QQEligibility{
        public QQCoverage Coverage;
        public QQEligibility(QQCoverage Coverage){
            this.Coverage = Coverage;
        }
    }
    public class QQCoverage{
        public Boolean FullTimeEmployeesSpouseDepen;
        public Boolean RetiredEmployeesAndDepend;
        public Boolean DomesticPartnerOppSex;
        public Boolean DomesticPartnerSameSex;
        public Boolean Domicile;
        public Boolean PartTimeEmployees;
        public Boolean Others;
        public QQCoverage(Boolean FullTimeEmployeesSpouseDepen, 
                          Boolean RetiredEmployeesAndDepend, 
                          Boolean DomesticPartnerOppSex, 
                          Boolean DomesticPartnerSameSex, 
                          Boolean Domicile, 
                          Boolean PartTimeEmployees, 
                          Boolean Others)
        {
            this.FullTimeEmployeesSpouseDepen = FullTimeEmployeesSpouseDepen;
            this.RetiredEmployeesAndDepend = RetiredEmployeesAndDepend;
            this.DomesticPartnerOppSex = DomesticPartnerOppSex;
            this.DomesticPartnerSameSex = DomesticPartnerSameSex;
            this.Domicile = Domicile;
            this.PartTimeEmployees = PartTimeEmployees;
            this.Others = Others;
        }
    }
    public class QQProduct{
        public QQNetworks[] Networks;
        public QQProduct(QQNetworks[] Networks)
        {
            this.Networks= Networks;
        }
    }
    public class QQNetworks{
        //public Boolean AdultAndChildOnly;   
        //public Integer ClassType;  
        //public Decimal Coinsurance; 
        public Boolean DentalAccidentCoverage;  
        public Decimal FamilyDeductible;    
        //public Decimal FamilyLifetimeMax;  
        public Boolean FourthQuarterCarryOver; 
        public Decimal IndividualDeductible;   
        //public Decimal IndividualLifetimeMax;  
        public Boolean IsWellnessBenefit;   
        public Boolean MissingToothExclusion;   
        public String NetworkID;    
        //public Decimal OOPFamilyMax;    
        //public Decimal OOPSingleMax;   
        public Boolean TakeOver;  
        public Decimal TMJIndividual;   
        public Integer TotalVariations; // Not Used - still sending for PEGA's convinence
        //public Decimal WaitingPeriod;   
        public Boolean WaiveDeductible; 
        public Boolean WaiveOnInitialEnrolees;  
        public QQBenefitGroupers[] BenefitGroupers;
        //Iteration 3
        public Boolean AccidentRider;
        public Decimal AnnualMaximum;
        public Boolean BenefitDifferential;
        public String COB;
        public Integer ClassICoinsurance;
        public Integer ClassIICoinsurance;
        public Integer ClassIIICoinsurance;
        public Decimal TMJCoinsurance;
        public Integer OrthoCoinsurance;
        public String IncidentPlanBenefitStartLevel;
        public Decimal LifetimeDeductible;
        //public Boolean OrthoLifetimeMax;
        public Decimal OrthoLifetimeMax;
        public Boolean OrthoTakeOver;
        public Decimal OrthoMax;
        public String OrthodonticCoverage;
        public Integer OrthoWaitingPeriodMonths; // COnversion required
        public String WaitingPeriodComments;
        public Boolean WaiveClassIDeductible;
        public Boolean WaiveClassIIDeductible;
        public Boolean WaiveClassIMaximum;
        public Boolean VirginOrtho;
        
        public Boolean SealantsToClassI;
        public Boolean Class3WaitingPeriod;
        public Integer Class3WaitingPeriodMonths;
        public Boolean TMJIndicator;
        public String TMJMaximum;
        public Decimal PerIndividual;
        public Boolean IncludesImplants;
        public Boolean DeductibleTakeover;
        public Boolean AnnualMaxTakeover;
        public Boolean OrthoMaxTakeover;
        public Boolean OrthoWaitingPeriod;
        public String OWPNumberOfMonths;
        public Decimal OrthoDeductible;
        public Decimal OrthoAnnualMax;
        
    }
    public class QQBenefitGroupers {
        public String ClassType;  
        public Integer Coinsurance; 
        public String Name; 
        public String Code;
        public QQBenefits[] Benefits;
        public QQBenefitGroupers(
            String ClassType,  
            Integer Coinsurance,    
            String Name, 
            String Code, 
            QQBenefits[] Benefits)
        {
            this.ClassType = ClassType;
            this.Coinsurance = Coinsurance;
            this.Name = Name;
            this.Code = Code;
            this.Benefits = Benefits;
        }
    }
    public class QQBenefits {
        public Integer Coinsurance;
        public String Name; 
        public String Code;
        public QQBenefits (Integer Coinsurance, String Name, String Code)
        {
            this.Coinsurance = Coinsurance;
            this.Name = Name;
            this.Code = Code;
        }
    }
    public class QQSegments {
        
        public String SegmentID;
        public Decimal EligibleEmployees;  
        public String SegmentName;
        public Date SegEffectiveDate;
        public Date SegEndDate; 
        public String Type;
        //Employees and Enrollees
        public Decimal TotalEmployees;
        public Decimal  EligiblePrimaryEnrollees;
        public Decimal TotalEmployeesforsegments;
        public Decimal EligiblePrimaryEnrolleesforSegment;
        public QQSegments(
            Integer EligibleEmployees,
            String SegmentName)
        {
            this.EligibleEmployees = EligibleEmployees;
            this.SegmentName = SegmentName;
        }
    }
    public class QQTierDetails {
        public String ContractTypeCode; 
        public Decimal Enrollees;   
        public String TierType;
        public Decimal CurrentRate;
        public Decimal CurrentCarrierRate;
        public Decimal CurrentCarrierRenewalRate;
        
        public Decimal TotalCensus;
        public Decimal RenewalCurrentChange;
        public Decimal ManualCurrentChange;
        public Decimal ExperienceCurrentChange;
        public Decimal CarRates;
        public Decimal IncrementalRates;
        public String ProposedNetAdmin;
        public String ProposedCarsRatio;
        public String PrpsdIncrAdmRatio;
        public String Commission;
        public String TotalProposedAdmin;  
        
        public QQTierDetails(){}
        public QQTierDetails(
            String ContractTypeCode,
            Decimal Enrollees,
            String TierType,
            Decimal TotalCensus,
            Decimal RenewalCurrentChange,
            Decimal ManualCurrentChange,
            Decimal ExperienceCurrentChange,
            Decimal CarRates,
            Decimal IncrementalRates,
            String ProposedNetAdmin,
            String ProposedCarsRatio,
            String PrpsdIncrAdmRatio,
            String Commission,
            String TotalProposedAdmin )
        {
            this.ContractTypeCode = ContractTypeCode;
            this.Enrollees = Enrollees;
            this.TierType = TierType;
            this.TotalCensus = TotalCensus;
            this.RenewalCurrentChange = RenewalCurrentChange;
            this.ManualCurrentChange = ManualCurrentChange;
            this.ExperienceCurrentChange = ExperienceCurrentChange;
            this.CarRates = CarRates;
            this.IncrementalRates = IncrementalRates;
            this.ProposedNetAdmin = ProposedNetAdmin;
            this.ProposedCarsRatio = ProposedCarsRatio;
            this.PrpsdIncrAdmRatio = PrpsdIncrAdmRatio;
            this.Commission = Commission;
            this.TotalProposedAdmin = TotalProposedAdmin;                         
        }
    }
    
    public class GVPlan {
        public Boolean Buyup;
        public Boolean DualChoice;
        public Boolean BenefitDifferential;
        public Boolean EOC;
        public Integer DependentAge;
        public Integer StudentAge;
        public Boolean Section125Ind;
        public Decimal EmployerContriEmployee;
        public Decimal EmployerContriEmployeeDollar;
        public Decimal EmployerContriDependent;
        public String ProductName;
        public String GroupName;
        public String GroupNumber; 
        public QQCarrier[] Carriers;
        public QQEligibility Eligibility;
        //public GVProducer[] ProducerInfo;
        //public QQTierDetails[] TierDetails;
    }
    
    public class GVProducer {
        public String ProducerName;
        public String ProducerNumber;
        public String ProducerType;
        public String TIN;
        public QQAddressList[] AddressList;
    }
    public class MTVServiceElements {
        //public MTVAccount Account;
        public MTVContract Contract;
    }
    public class MTVAccount {
        public String AccountName;
        public QQAccountManager AccountManager;
        public QQAddressList[] AddressList;
        public MTVContract[] Contract;
    }
    public class MTVContract {
        public String GroupNumber;
        public QQAddressList[] AddressList;
        public MTVContact[] Contact;
        public MTVPlans[] Plans;
    }
    public class MTVContact {
        public String FirstName;
        public String LastName;
        public String Role;
        public QQAddressList[] AddressList;
    }
    public class MTVPlans {
        public String PlanName;
        public String ProductName;
        public String ContractType;
        
        public Integer DependentAgeLimit;
        //public Boolean DomesticPartnerOppositeSex;
        //public Boolean DomesticPartnerSameSex;
        public String EffectiveDate;
        public String PaymentFrequency;
        //public Boolean RetiredEmployeesDependent;
        public Integer StudentAge;
        public Integer StudentAgeLimit;
        public Boolean SuppressIDCards;
        public Boolean TOA;
        //public String BenefitPackageId;
        public String PlanId;
        public String PlanType;
        //public MTVSegment[] Segment;
    }
    public class MTVSegment {
        public String SegmentName;
    }
    
    public class OCROnyxConversion {
        public String OnyxAccountID;
        public String IncidentID;
        public String SFDCAccountID;
        public boolean Stage;
        Public String SFDCNotes;
        // public OCROpenTasks[] OpenTasks;
        public OCRGroupInfo GroupInfo;
        public QQQAccount Account;
        public QQOpportunity Opportunity;
        public string DueDate;
        public string EffectiveDate;
        public QQSFDCCase SFDCCase;
        /*  public OCROnyxConversion (QQQAccount Account, QQOpportunity Opportunity, OCROpenTasks[] OpenTasks,OCRGroupInfo GroupInfo){
this.OpenTasks = OpenTasks;
this.GroupInfo = GroupInfo;
this.Account = Account;
this.Opportunity = Opportunity;
}*/
        public OCROnyxConversion(){
            
        }
    }
    public class OCROpenTasks{
        public String TaskID;
        public String IncidentID;
        public String TaskCategoryDesc;
        public String StatusDesc;
        public String AssignedTo;
        public String TaskTypeDesc;
        public String TaskDesc;
        public String Notes;
    }
    public class OCRGroupInfo {
        public String GroupNumber;
        public String GroupName; 
    }
    
    public class QQUWNotes {//UWNotes start
        public String Notes;
        public String pyUserName;
        public String pxCreateDateTime;
    }//UWNotes End
    
    public class QQNotes {
        public String Notes;
        public DateTime SalesNotesTimeStamp;
        public QQNotes(String Notes){
            this.Notes = Notes;
        }
        public QQNotes(String Notes, DateTime SalesNotesTimeStamp){
            this.Notes = Notes;
            this.SalesNotesTimeStamp = SalesNotesTimeStamp;
        }
    }
    //Added for PC-12024
    public class QQWithdrawList{
        public String CaseID;    
    }
    //Upto this for PC-12024
    //Added for PC-11764
    public class QQAccountNC{
        public String AccountID;
        public String AccountNumber;
        public String AccountName;
    }
    public class QQOpportunityNC{
        public String OpportunityID;
        public String EventGroupName;
    }
    //Upto this for PC-11764   
}