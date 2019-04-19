/**
 * @description 
 * 
 * @author
 *
 * @change Hitendar  11/06/2015 Added the rate sheet logic for Not Released plans also in RFP callout as rate sheet was not sent for not release plans in re-rate
 * @change Rushikesh 12/05/2015 Added logic to map AccountType for Adhoc webservice Request to Pega
 * @change Rajesh    12/29/2015 Conversion data click renow button some logic added in P2EwWizRateSheets below line add if condition
 * @change HCL       08/15/2016 Get Benefit Packages from BenefitPackage Object
 *                              Consider only new Rate Sheets for Renewal 
 *                              Update PRCaseID to the JSON in implementation phase
 * @change HCL       09/02/2016 Updated logic to fix Division list in Ratesheets issue
 *                              Assigned Division Number to Segment Name instead of actual Segment Name in JSON
 * @change Santhosh  10/14/2017 Added logic for Rich Text Area requirement
 */

public class P2EhPegaCallouts {
    public P2EwWizCache cache { private get; set; }
    public Account acc { private get; set; }
    public Product2 prod { private get; set; }
    public Opportunity opp { private get; set; }
    public Set<Id> prodIds { private get; set; }
    public Quote quot { private get; set; }
    private Id quotId;
    /***** Change By HCL MM *****/
    @TestVisible private list<Document_Info__c> doclist = new list<Document_Info__c>();
    @TestVisible private Id chngRenOppId;
    public Case cas { private get; set; } 
    private Map<String, Product2> allPlansUW;
    @TestVisible private List<Contact> conList;
    private String username;
    private String password;
    private String authorizationHeader;
    private Map<String, String> headerMap;
    public map<String,Pega__c> mapUserDetails { get; set; }
    public boolean isbatch { get; set; }
    Public static String rImplCaseId;   // Added for Re-IMPL Process
    private String method;
    private String endPointURL;
    private String httpRespBody;
    private String parentImplStatus;
    private String parentImplCaseId;
    public static Map<String, String> mapStateStateCode;
    private Map<Id, OpportunityLineItem> mapProdOLI;
    private Map<String,List<OpportunityLineItem>> mapGroupOLI = new Map<String,List<OpportunityLineItem>>();//PC-13770
    private Map<String, Id> mapRFPQId;
    Decimal totalCommission = 0;
    List<Opportunity> lstOpportunityNC = new List<Opportunity>(); //Added for PC-11764
    static{
        mapStateStateCode = new Map<String, String>();
        for(US_State__c USSC: [Select Id, Name, State__c, State_Code__c From US_State__c]){
            mapStateStateCode.put(USSC.State__c, USSC.State_Code__c);
        }
    }
    
    public P2EhPegaCallouts(){}
    
    public P2EhPegaCallouts(Account acc, Product2 prod, Opportunity opp){
        this.acc = acc;
        this.prod = prod;
        this.opp = opp;
        init();
    }
    
    public P2EhPegaCallouts(Account acc1, Opportunity opp1, Case cas1, String req){
        this.acc = acc1;
        this.opp = opp1;
        this.cas = cas1;
        init();
        if(req=='rfi'){
            getRFI();
        }
        try{
            if(req=='Term'){            
                getTermTransfer();
            }
        }
        catch(P2EException e){
            throw e;
        }   
    }
    public P2EhPegaCallouts(Account acc1, Opportunity opp1, Case cas1){
        this.acc = acc1;
        this.opp = opp1;
        this.cas = cas1;
        init();
        getRFI();
    }
    
    //Added for PC-12024
    public P2EhPegaCallouts(Quote Quot){
        this.quot = Quot;    
        withdrawQuote();
    }    
    //Upto this for PC-12024    
    //Added for PC-11764
    public P2EhPegaCallouts(Account Acc1, List<Opportunity> lstOpp){
        this.acc = Acc1;
        this.lstOpportunityNC = lstOpp;
        AccountNameChange();
    }
    //Upto this for PC-11764    
    public P2EhPegaCallouts(Account acc, Opportunity opp, Case cas, Set<Id> prodIds){
        this.acc = acc;
        this.opp = opp;
        this.cas = cas;
        this.prodIds = prodIds;
        mapProdOLI = new Map<Id, OpportunityLineItem>();
        mapRFPQId = new Map<String, Id>();
        Set<String> rfpCases = new Set<String>();
        for(OpportunityLineItem oli : [select id,Effective_Date__c,IsRateupdated__c,RFP_Case_Id__c,Parent_Impl_Case_Id__c,Par_Impl_case_Id_Hide__c,Par_Impl_case_status_Hide__c,Parent_Impl_Case_Status__c, Action__c, Group_Number__c, Decision_Status__c, Product2Id from OpportunityLineItem Where OpportunityId =: opp.Id and  Product2Id in: prodIds]){
            mapProdOLI.put(oli.Product2Id, oli);
            rfpCases.add(oli.RFP_Case_Id__c);
        }
        //PC-13770 Start
        for(OpportunityLineItem oli : [select id,Effective_Date__c,IsRateupdated__c,RFP_Case_Id__c,Parent_Impl_Case_Id__c,Par_Impl_case_Id_Hide__c,Par_Impl_case_status_Hide__c,Parent_Impl_Case_Status__c, Action__c, Group_Number__c, Decision_Status__c, Product2Id from OpportunityLineItem Where OpportunityId =: opp.Id]){
            if(oli.Group_Number__c!=null){
                if(mapGroupOLI.get(oli.Group_Number__c)==null){
                    mapGroupOLI.put(oli.Group_Number__c, new List<OpportunityLineItem>());
                }
                mapGroupOLI.get(oli.Group_Number__c).add(oli);
            }    
        }//PC-13770 end
        system.debug('RFP@@@'+rfpCases);
        for(Quote q : [select Id, RFP_Case_Id__c from Quote where RFP_Case_Id__c in: rfpCases]){
            mapRFPQId.put(q.RFP_Case_Id__c, q.Id);
        }
        init();
    }
    
    public P2EhPegaCallouts(P2EwWizCache cache){
        this.acc = cache.selectedAccount;
        this.opp = cache.selectedOpportunity;
        this.quot = cache.createdQuote;
        this.cas = cache.createdCase;
        this.cache = cache;
        init();
    }
    
    public void init(){
        if(prodIds==null && cache!=null){
            prodIds = new Set<Id>();
            system.debug('---115->'+cache.allPlansMap);
            for(P2EwPlanDesignLite pdl : cache.allPlansMap.values()){
                prodIds.add(pdl.ProductId);
            }
        }
        allPlansUW = new Map<String, Product2>();
        for(Product2 prod : [select id, planId__c, UWQuestionnaire__c, Implementation_Notes__c,GroupPlanName__c,Benefit_Notes__c from Product2 where id in: prodIds]){
            allPlansUW.put(prod.planId__c, prod);
        }
        if(quot!=null){
            quotId = quot.Id;
        }
         if(cache!=null){
            chngRenOppId = cache.selectedOpportunity.Renewal_Opportunity__c;
            if(cache.createdquote!=null){
                doclist = [select Document_Type__c,Due_Date__c,Notes__c,Quote__c from Document_Info__c where Quote__c =:cache.createdQuote.Id];
            }
        }
        if(cache==null && opp!=null && opp.type=='Change'){
            chngRenOppId = [select id, Renewal_Opportunity__c from Opportunity where id =: opp.id].Renewal_Opportunity__c;
        }
        isbatch = false;
        List<AccountContactRole__c> acr = [Select id,Contact__c from AccountContactRole__c where Role__c = 'Renewal Recipient' and Account__c =: acc.id];
        Set<Id> cid = new set<Id>();
        for(AccountContactRole__c aco : acr){
            cid.add(aco.Contact__c);
        }
        conList = Database.Query(P2EhUtility.getQuery('Contact') + 'Where id IN: cid');
        try{
            Pega__c callDetails = Pega__c.getInstance('PegaUser1');
            endPointURL = callDetails.endPointURL__c;
            method = callDetails.method__c;
            username = callDetails.username__c;
            password = callDetails.password__c;
            
            Blob headerValue = Blob.valueOf(username + ':' + password);
            authorizationHeader = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
            headerMap = new Map<String, String>();
            headerMap.put('Authorization', authorizationHeader);
            headerMap.put('Accept-Encoding', 'gzip');
        }catch(Exception e){
            //
            System.debug(' Error ... ' + e.getMessage());
        }
    }
    
    public P2EwProductOfferedResponse checkProductEligibility(){
        P2EwProductOfferedRequest prodReq;
        P2EwProductOfferedRequest.ProductRequest qa;
        try{
            prodReq = new P2EwProductOfferedRequest();
            qa = new P2EwProductOfferedRequest.ProductRequest(acc.Situs_State__c, acc.NumberOfEmployees, acc.Industry, acc.Business_Type__c);
            prodReq.ProductLimit = qa;
            if(Test.isRunningTest()){
                httpRespBody = '{"ProductLimit":{"Products":[{"Name":"Fee For Service","ContractTypes":["ASC (Self funded)","Non-Retention (Non-Participating)","Retention (Participating)","Guaranteed Administration (Participating)","ASC with Stop Loss"],"Plans":[]},{"Name":"DHMO","ContractTypes":["Non-Retention (Non-Participating)"],"Plans":["10 A","10 C"]}]}}';
            }else{
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, prodReq.generate(),'Pega',username,'checkProductEligibility');
                //httpRespBody = '{"ProductLimit":{"Products":[{"Name":"Fee For Services","ContractTypes":["ASC (Self funded)","Non-Retention (Non-Participating)","Retention (Participating)","Guaranteed Administration (Participating)","ASC with Stop Loss"],"Plans":[]},{"Name":"DHMO","ContractTypes":["Non-Retention (Non-Participating)"],"Plans":["10 A","10 C"]}]}}';
            }
        }catch(Exception e){
            
            return null;
        }
        P2EwProductOfferedResponse prodResp = null;
        try{
            if(httpRespBody!=null){
                prodResp = P2EwProductOfferedResponse.parse(httpRespBody);
                return prodResp;
            }
        }catch(Exception e){
            
            return null;
        }
        return null;
    }
    
    //Added for PC-12024
    public void withdrawQuote(){
        Set<String> CaseIds = new Set<String>();
        List<P2EwPegaService.QQWithdrawList> lstWList;
        P2EwWithdrawRequest withdrawReq = new P2EwWithdrawRequest();
        withdrawReq.ServiceType = 'Withdraw';
        system.debug('@@@@@@@test'+quot);
        system.debug('SSSSSSSSS'+quot.RFP_Case_Id__c);
        if(quot.RFP_Case_Id__c != Null || quot.originalcaseid__c != Null){
            if(quot.RFP_Case_Id__c != Null){
                CaseIds.add(quot.RFP_Case_Id__c);
            }
            if(quot.originalcaseid__c != Null){
                CaseIds.add(quot.originalcaseid__c);
            }
            List<OpportunityLineItem> lstOliRecs = [Select Id, OpportunityId, RFP_Case_Id__c, Parent_Impl_Case_Id__c From OpportunityLineItem where RFP_Case_Id__c =: quot.RFP_Case_Id__c OR RFP_Case_Id__c =: quot.originalcaseid__c];
            if(lstOliRecs.size() > 0){
                for(OpportunityLineItem Oli: lstOliRecs){
                    if(Oli.Parent_Impl_Case_Id__c != Null){
                        CaseIds.add(Oli.Parent_Impl_Case_Id__c);
                    }
                }
            }            
        }
        if(CaseIds.size() > 0){
            lstWList = new List<P2EwPegaService.QQWithdrawList>();
            P2EwPegaService.QQWithdrawList wList;
            for(String CIds: CaseIds){
                wList = new P2EwPegaService.QQWithdrawList();
                wList.CaseID = CIds;
                lstWList.add(wList);
            }
        }
        withdrawReq.WithdrawCaseList = lstWList;
        try{
            Pega__c callDetails = Pega__c.getInstance('PegaUser1');
            endPointURL = callDetails.endPointURL__c;
            method = callDetails.method__c;
            username = callDetails.username__c;
            password = callDetails.password__c;
            
            Blob headerValue = Blob.valueOf(username + ':' + password);
            authorizationHeader = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
            headerMap = new Map<String, String>();
            headerMap.put('Authorization', authorizationHeader);
            headerMap.put('Accept-Encoding', 'gzip');
        }catch(Exception e){
            //
        }        
        system.debug(withdrawReq.generate() + 'Line 201'+method);
        if(!Test.isRunningTest()){
            httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, withdrawReq.generate(),'Pega',username,'Withdraw');
        }else{
            httpRespBody = '{"WithdrawStatus": "Passed"}';   
        }
        system.debug(httpRespBody+'Line 207');        
    }
    //Upto this for PC-12024    
    //Added for PC-11764
    public void AccountNameChange(){
        P2EwAccountNameChange wANCReq= new P2EwAccountNameChange();        
        P2EwPegaService.QQAccountNC ANC = new P2EwPegaService.QQAccountNC();
        List<P2EwPegaService.QQOpportunityNC> listONC = new List<P2EwPegaService.QQOpportunityNC>();
        if(acc != Null){
            ANC.AccountName = acc.Name;
            ANC.AccountNumber = acc.Account_Number__c;
            ANC.AccountID = acc.Id;
        }
        if(lstOpportunityNC != Null && lstOpportunityNC.size() > 0){
            P2EwPegaService.QQOpportunityNC ONC;
            for(Opportunity oppRec: lstOpportunityNC){
                ONC = new P2EwPegaService.QQOpportunityNC();
                ONC.OpportunityID = oppRec.Id;
                ONC.EventGroupName = oppRec.Name;
                listONC.add(ONC);
            }
        }
        wANCReq.ServiceType = 'Account';
        wANCReq.Account = ANC;
        wANCReq.OpportunityList = listONC;
        
        try{
            Pega__c callDetails = Pega__c.getInstance('PegaUser1');
            endPointURL = callDetails.endPointURL__c;
            method = callDetails.method__c;
            username = callDetails.username__c;
            password = callDetails.password__c;
            
            Blob headerValue = Blob.valueOf(username + ':' + password);
            authorizationHeader = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
            headerMap = new Map<String, String>();
            headerMap.put('Authorization', authorizationHeader);
            headerMap.put('Accept-Encoding', 'gzip');
        }catch(Exception e){
            //
        }        
        system.debug(wANCReq.generate() + 'Line 201'+method);
        if(!Test.isRunningTest()){
            httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, wANCReq.generate(),'Pega',username,'AccountNameChange');
        }else{
            httpRespBody = '{"CaseStatus": "SUCCESS"}';   
        }
    }
    //Upto this for PC-11764    
    public void getRFI(){
        P2EwRFIRequest rfiReq = null;
        P2EwRFIResponse rfiResp = null;
        /* Account - Start */
        List<P2EwRFIPegaService.RFIAddressList> addressList;
        P2EwRFIPegaService.RFIAccountExecutive rfiAE;
        P2EwRFIPegaService.RFIAccountManager rfiAM;
        User ae;
        try{
            addressList = new List<P2EwRFIPegaService.RFIAddressList>();
            addressList.add(new P2EwRFIPegaService.RFIAddressList(acc.BillingStreet, acc.BillingStreet, '', acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, 'Shipping', true)); //This is main address in UI
            addressList.add(new P2EwRFIPegaService.RFIAddressList(acc.ShippingStreet, acc.ShippingStreet, '', acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, 'Billing', false));//This is Billing address in UI
            
            try{
                ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
            }
            catch(Exception exp){
                ae = null;
            }
            if(ae!=null){
                rfiAE = new P2EwRFIPegaService.RFIAccountExecutive(ae.Name, ae.Email);
                rfiAE.ExternalID = ae.Username;
                rfiAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                rfiAE = new P2EwRFIPegaService.RFIAccountExecutive('No AE assigned','');
            }
            User am;
            try{
                am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
            }
            catch(Exception exp){
                am = null;
            }
            if(am!=null){
                rfiAM = new P2EwRFIPegaService.RFIAccountManager(am.Name, am.Email);
                rfiAM.ExternalID = am.Username;
                rfiAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                rfiAM = new P2EwRFIPegaService.RFIAccountManager ('No AM assigned','');
            }
        }catch(Exception e){
            
            //return null;
        }
         
        List<P2EwRFIPegaService.RFINAIC> naicLst = new List<P2EwRFIPegaService.RFINAIC>();
        P2EwRFIPegaService.RFIAccount RFIAccount = new P2EwRFIPegaService.RFIAccount();
        RFIAccount.AccountID = acc.Id;
        RFIAccount.NumberOfEmployees = acc.NumberOfEmployees;
        RFIAccount.AccountExecutive = rfiAE;
        RFIAccount.AccountManager = rfiAM;
        RFIAccount.AddressList = addressList;
        RFIAccount.AccountName = acc.Name;
        if(acc.ParentId != Null){
        System.Debug('acc parentid***'+acc.ParentId);        
            RFIAccount.ParentAccountID = acc.ParentId; //Added for PC-12835
            RFIAccount.ParentName = [Select Id, Name From Account Where Id =: acc.ParentId].Name; //Added for PC-12835
        } 
        RFIAccount.AccountNumber = acc.Account_Number__c;
        RFIAccount.SitusState = acc.Situs_State__c;
        RFIAccount.BidSpecification = acc.Bid_Specification__c;
        if(acc.NaicsCode != null){
            naicLst.add(new P2EwRFIPegaService.RFINAIC(acc.NaicsCode,acc.NaicsDesc));
            RFIAccount.NAICList = naicLst;            
        }
        else{
            naicLst.add(new P2EwRFIPegaService.RFINAIC('unknown', 'unknown'));
            RFIAccount.NAICList = naicLst;
        }
        /* Account - End :: RFIAccount */
        
        /* Opportunity - Start */
        P2EwRFIPegaService.RFIOpportunity RFIOpportunity = new P2EwRFIPegaService.RFIOpportunity();
        if(opp != null){
            RFIOpportunity.OpportunityID = opp.Id;
            RFIOpportunity.Amount = opp.Amount;
            RFIOpportunity.Priority1 = opp.Priority_1__c;
            RFIOpportunity.Priority2 = opp.Priority_2__c;
            RFIOpportunity.Priority3 = opp.Priority_3__c;
            RFIOpportunity.Priority4 = opp.Priority_4__c;
            RFIOpportunity.Priority5 = opp.Priority_5__c;
            RFIOpportunity.AgeDistribution = null;
            RFIOpportunity.IsAutoRenewal = opp.AutoRenewal__c;        
            RFIOpportunity.DueDate =dateToStr(cas.Due_Date__c);
            
          //----------- Added For PC-11577
         /***** Change By HCL MM *****/   
         if((cas.Request_Type_RFI__c!=null && cas.Request_Type_RFI__c== 'Disruption Analysis') || Test.isRunningTest()){           
            RFIOpportunity.DisruptionPPOAndPremier = cas.Disruption_PPO_And_Premier__c;   
            RFIOpportunity.DisruptionDeltaCare = cas.Disruption_DeltaCare__c;
            RFIOpportunity.CurrentCarrier= cas.Current_Carrier__c;
            RFIOpportunity.CompetitorCarrier= cas.Competitor_Carrier__c;
            RFIOpportunity.CarrierRelatedNotes= cas.Carrier_related_notes__c;
            RFIOpportunity.CompetitorRelatedNotes= cas.Competitor_related_notes__c;
            RFIOpportunity.DATemplateSelection= cas.Template_SelectionDis__c;
            RFIOpportunity.DATemplateNotes= cas.DA_Template_Notes__c;  
                    
                    
        }
        /***** Change By HCL MM *****/   
        if((cas.Request_Type_RFI__c!=null && cas.Request_Type_RFI__c== 'Geo Access Report') || Test.isRunningTest()){           
            RFIOpportunity.GeoPPO= cas.Geo_Access_PPO__c;
            RFIOpportunity.GeoPPOAndPremier= cas.Geo_Access_PPO_And_Premier__c;
            RFIOpportunity.GeoPremier= cas.Geo_Access_Premier__c;
            RFIOpportunity.GeoDeltaCare= cas.Geo_DeltaCare__c;
            RFIOpportunity.AllEmployees = cas.Combine_Employees__c;
            RFIOpportunity.RetiredOnly = cas.Retired_Only__c;
            RFIOpportunity.ActiveOnly = cas.Active_Only__c;
            RFIOpportunity.OtherTypeofFilter = cas.Other_Type_of_Filter__c;         
            RFIOpportunity.UrbanSuburbanRural = cas.Urban_Suburban_Rural__c;      
            RFIOpportunity.GDOnly= cas.GD_Only__c; 
            RFIOpportunity.SPOnly= cas.SP_Only__c;       
            RFIOpportunity.GDSPCombined= cas.GD_SP_Combined__c;          
            RFIOpportunity.GDandSP8Miles= cas.X2_GD_SP_in_8_miles__c;
            RFIOpportunity.GDandSP10Miles= cas.X2_GD_SP_in_10_miles__c;            
            RFIOpportunity.GDandSP15Miles= cas.X2_GD_SP_in_15_miles__c;
            RFIOpportunity.GDSP10Milesand1SP15Miles= cas.X2_GD_in_10_miles_1_SP_in_15_miles__c;
            
            RFIOpportunity.GDSP8MilesSpecialtyType= cas.GDSP8MilesSpecialtyType__c;
             
            RFIOpportunity.GDSP10MilesSpecialtyType= cas.GDSP10MilesSpecialtyType__c;
            RFIOpportunity.GDSP15MilesSpecialtyType= cas.GDSP15MilesSpecialtyType__c;
            RFIOpportunity.GD10Miles1SP15MilesSpecialtyType= cas.GD10Miles1SP15MilesSpecialtyType__c;
            RFIOpportunity.UrbanSpecialtyType= cas.UrbanSpecialtyType__c;
            RFIOpportunity.RuralSpecialtyType= cas.RuralSpecialtyType__c;
            RFIOpportunity.SuburbanSpecialtyType= cas.SuburbanSpecialtyType__c;          
            RFIOpportunity.Rural2Providers= cas.Rural_2_Providers__c; 
            RFIOpportunity.Urban2Providers= cas.Urban_2_Providers__c; 
            RFIOpportunity.Suburban2Providers= cas.Suburban_2_Providers__c; 
            RFIOpportunity.GeoTemplateSelection= cas.Template_Selection__c;      
            RFIOpportunity.GeoTemplateNotes= cas.Geo_Template_Notes__c;             
     
         //   RFIOpportunity.State= cas.State__c;
            RFIOpportunity.CBSA= cas.CBSA__c;
            RFIOpportunity.County = cas.County__c;
            RFIOpportunity.City= cas.City__c;
            RFIOpportunity.Zip= cas.Zip__c;        
            RFIOpportunity.CensusPasswordifApplicable= cas.Census_Password_if_Applicable__c; 
            if(cas.Other_Notes__c != Null){      
            RFIOpportunity.OtherNotes = EncodingUtil.base64Encode(Blob.valueOf(cas.Other_Notes__c));  
            }      
        }else if(cas.Request_Type_RFI__c!= null && cas.Request_Type_RFI__c== 'Feasibility Review'){       //PC-12407  
         //RFIOpportunity.DueDateFeasibilityReview= dateToStr(cas.Due_Date__c); //dateToStr(cas.Feasibility_Review_Expected_Date__c);       
           RFIOpportunity.FeasibilityReviewExpectedNotes= cas.Feasibility_Review_Expected_Notes__c;     
        }     
         //---------Added for PC-11577    
            
            
            
            // Broker
            List<OpportunityContactRole__c> OCRList;
            List<P2EwRFIPegaService.RFIBroker> RFIBrokers = new List<P2EwRFIPegaService.RFIBroker>();
            try{
                OCRList = [select Id, Contact__r.AccountId, Contact__r.Account.Name, 
                    Contact__r.Account.Broker_Number__c, Contact__r.Account.BillingStreet, Contact__r.Account.BillingCity, 
                    Contact__r.Account.BillingState, Contact__r.Account.BillingCountry, Contact__r.Account.BillingPostalCode, 
                    Contact__r.Account.ShippingStreet, Contact__r.Account.ShippingCity, 
                    Contact__r.Account.ShippingState, Contact__r.Account.ShippingCountry, Contact__r.Account.ShippingPostalCode, 
                    Contact__r.Account.Phone, Contact__r.Account.Fax, Contact__r.Account.Company_Email__c, Contact__r.Account.RecordType.Name from OpportunityContactRole__c where 
                    Contact__r.Account.RecordType.Name = 'Producer Firm' and Opportunity__c =: opp.Id];
                
                for(OpportunityContactRole__c OCR : OCRList){
                    P2EwRFIPegaService.RFIBroker RFIBroker = new P2EwRFIPegaService.RFIBroker();
                    RFIBroker.BrokerID = OCR.Contact__r.Account.Broker_Number__c;
                    RFIBroker.BrokerName = OCR.Contact__r.Account.Name;
                    RFIBroker.Type = OCR.Contact__r.Account.RecordType.Name;
                    RFIBroker.Commission = null;
                    //List<P2EwRFIPegaService.RFIAddressList> addressLst = new List<P2EwRFIPegaService.RFIAddressList>();
                    P2EwRFIPegaService.RFIAddressList address = new P2EwRFIPegaService.RFIAddressList(OCR.Contact__r.Account.BillingStreet, OCR.Contact__r.Account.BillingStreet, '', OCR.Contact__r.Account.BillingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(OCR.Contact__r.Account.BillingState), OCR.Contact__r.Account.BillingPostalCode, 'Shipping', true); // This is main address in UI
                    //addressLst.add(new P2EwRFIPegaService.RFIAddressList(OCR.Contact__r.Account.ShippingStreet, OCR.Contact__r.Account.ShippingStreet, '', OCR.Contact__r.Account.ShippingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, mapStateStateCode(OCR.Contact__r.Account.ShippingState), OCR.Contact__r.Account.ShippingPostalCode, 'Shipping', false));
                    RFIBroker.Address = address;
                    RFIBrokers.add(RFIBroker);
                }
                RFIOpportunity.Broker = RFIBrokers;
            }catch(Exception e){
                RFIOpportunity.Broker = null;
            }
            
            RFIOpportunity.Census = null;
        }else{
            RFIOpportunity = null;
        }
        /* Opportunity - End :: RFIOpportunity */
        
        /* Case - Start */
        P2EwRFIPegaService.RFICase RFICase = new P2EwRFIPegaService.RFICase();
        RFICase.CaseID = cas.Id;
        RFICase.Subject = cas.Subject;
        RFICase.Description = cas.Description;
        RFICase.DueDate = dateToStr(cas.Due_Date__c);
        RFICase.Source = cas.Origin;
        //if(cas.Request_Type__c == 'Form 5500'){     
            RFICase.GroupNumber = cas.Group__c;     
            RFICase.DivisionNumber = cas.Division_Number__c;        
            RFICase.Form5500StartDate = dateToStr(cas.Form_5500_Beginning_Period__c);       
            RFICase.Form5500EndDate = dateToStr(cas.Form_5500_Ending_Period__c);        
            //RFICase.ContractStartDate = dateToStr(cas.Contract_Beginning_Period__c);        
            //RFICase.ContractEndDate = dateToStr(cas.Contract_Ending_Period__c);     
        //}
        /* Case - End :: RFICase */
        
        P2EwRFIPegaService.RFIProposal rfiProposal = new P2EwRFIPegaService.RFIProposal(RFIOpportunity, RFIAccount, RFICase);
        rfiReq = new P2EwRFIRequest();
        rfiReq.ServiceType = 'RFI';
        rfiReq.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604        
        if (cas.Request_Type__c == 'DHMO Plan Comparison'){
             rfiReq.SubType             = 'DHMOPlanComp';
        } else if (cas.Request_Type__c == 'Disruption Analysis'){
             rfiReq.SubType             = 'DisruptionAnalysis';
        } else if (cas.Request_Type__c == 'Fee Analysis'){
             rfiReq.SubType             = 'FeeAnalysis';
        } else if (cas.Request_Type__c == 'Benefit Deviation'){
             rfiReq.SubType             = 'DeviationReviewAnalysis';
        } else if (cas.Request_Type__c == 'Questionnaire'){
             rfiReq.SubType             = 'Questionnaire';
        }else if (cas.Request_Type__c == 'Contact Sheets'){
             rfiReq.SubType             = 'ContactSheets';
        }else if (cas.Request_Type__c == 'Highlight Sheets'){
             rfiReq.SubType             = 'HighlightSheets';
        }else if (cas.Request_Type__c == 'Contract Document'){
             rfiReq.SubType             = 'ContractDocument';
        }else if (cas.Request_Type__c == 'Claims Re-Pricing'){
             rfiReq.SubType             = 'Repricing';
        }else if (cas.Request_Type__c == 'Geo Access Report'){
             rfiReq.SubType             = 'GeoAccess';
        }else if (cas.Request_Type__c == 'ID card Printing Enrollment'){
             rfiReq.SubType             = 'IDCardPrintingEnrollment';
        }else if (cas.Request_Type__c == 'Nonstandard Billing Report'){
             rfiReq.SubType             = 'NonStandardBillingReport';
        }else if (cas.Request_Type__c == 'Provider Utilization'){
             rfiReq.SubType             = 'ProviderUtilization';
        }else if (cas.Request_Type__c == 'Network Discounts'){
             rfiReq.SubType             = 'NetworkDiscounts';
        }else if (cas.Request_Type__c == 'Provider Counts NW Comp'){
             rfiReq.SubType             = 'ProviderCountsNWComp';
        }else if (cas.Request_Type__c == 'Network Growth and Turnover'){
             rfiReq.SubType             = 'NetworkGrowthandTurnover';
        }else if (cas.Request_Type__c == 'Adhoc Provider Report'){
             rfiReq.SubType             = 'AdhocProviderReport';
        }else if (cas.Request_Type__c == 'Financial Experience'){
             rfiReq.SubType             = 'FinancialExperience';
        }else if (cas.Request_Type__c == 'Network Utilization'){
             rfiReq.SubType             = 'NetworkUtilization';
        }else if (cas.Request_Type__c == 'Maximum Report'){
             rfiReq.SubType             = 'MaximumReport';
        }else if (cas.Request_Type__c == 'Executive Summary'){
             rfiReq.SubType             = 'ExecutiveSummary';
        }else if (cas.Request_Type__c == 'DHMO Financial'){
             rfiReq.SubType             = 'DHMOFinancial';
        }else if (cas.Request_Type__c == 'DHMO Utilization'){
             rfiReq.SubType             = 'DHMOUtilization';
        }else if (cas.Request_Type__c == 'Actuarial Adhoc Report'){
             rfiReq.SubType             = 'ActuarialAdhocReport';
        }else if (cas.Request_Type__c == 'Form 5500'){      
             rfiReq.SubType             = 'Form5500'; 
         }else if(cas.Request_Type_RFI__c== 'Geo Access Report'){
             rfiReq.SubType             = 'GeoAccess';
        }else if(cas.Request_Type_RFI__c== 'Disruption Analysis'){
             rfiReq.SubType             = 'DisruptionAnalysis';
        }else if(cas.Request_Type__c == 'State/Federal Programs'){   //Added for 2-way communication
             rfiReq.SubType             = 'StateFederalPrograms';
        }else if(cas.Request_Type__c == 'D2C Adhoc Request'){
             rfiReq.SubType             = 'D2CAdhocRequest';
        }else if(cas.Request_Type__c == 'DHMO Utilization/Financial'){
             rfiReq.SubType             = 'DHMOUtilizationFinancial';
        }//Till here
        //------Added for PC-12407
        else if(cas.Request_Type_RFI__c== 'Feasibility Review'){
             rfiReq.SubType             = 'Feasibility Review';
        }else{
             rfiReq.SubType             = cas.Request_Type__c;
        }      
        
        rfiReq.Proposal    = rfiProposal;
               
        if(!Test.isRunningTest()){
            httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, rfiReq.generate(),'Pega',username,'getRFI');
        }else{
            httpRespBody = '{"Proposal":{"CaseStatus":"Pending-Review","CaseID":"G-2470"}}';   
        }
               
        //Frame Response
        if(httpRespBody!=null){
            try{
                rfiResp = P2EwRFIResponse.parse(httpRespBody);
                String validateRespStr = rfiResp.validateResponse();
            }catch(JSONException e){
                
            }catch(Exception e){
                                    
            }
            this.cas.UW_Case_ID__c = rfiResp.Proposal.CaseID;
            this.cas.Status = rfiResp.Proposal.CaseStatus;
            update cas;
        }
    }
    public void getTermTransfer(){//Term And Transfer code by Geetha START
        P2EwTermTransferRequest TTReq = null;
        P2EwTermTransferResponse ttResp = null;
        //Account - Start 
        List<P2EwTermTransferPegaService.TermAddressList> addressList;
        P2EwTermTransferPegaService.TermAccountExecutive termAE;
        P2EwTermTransferPegaService.TermAccountManager termAM;
        User ae;
        try{
            addressList = new List<P2EwTermTransferPegaService.TermAddressList>();
            addressList.add(new P2EwTermTransferPegaService.TermAddressList(acc.BillingStreet, acc.BillingStreet, '', acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, 'Shipping', true)); //This is main address in UI
            addressList.add(new P2EwTermTransferPegaService.TermAddressList(acc.ShippingStreet, acc.ShippingStreet, '', acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, 'Billing', false));//This is Billing address in UI
            
            try{
                ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
            }
            catch(Exception exp){
                ae = null;
            }
            if(ae!=null){
                termAE= new P2EwTermTransferPegaService.TermAccountExecutive(ae.Name, ae.Email);
                termAE.ExternalID = ae.Username;
                termAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                termAE = new P2EwTermTransferPegaService.TermAccountExecutive('No AE assigned','');
            }
            User am;
            try{
                am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
            }
            catch(Exception exp){
                am = null;
            }
            if(am!=null){
                termAM= new P2EwTermTransferPegaService.TermAccountManager(am.Name, am.Email);
                termAM.ExternalID = am.Username;
                termAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                termAM= new P2EwTermTransferPegaService.TermAccountManager ('No AM assigned','');
            }
        }catch(Exception e){
            
            //return null;
        }
         
        List<P2EwTermTransferPegaService.TermNAIC> naicLst = new List<P2EwTermTransferPegaService.TermNAIC>();
        P2EwTermTransferPegaService.TermAccount TermAccount = new P2EwTermTransferPegaService.TermAccount();
        TermAccount.AccountID = acc.Id;
        TermAccount.NumberOfEmployees = acc.NumberOfEmployees;
        TermAccount.AccountExecutive = termAE;
        TermAccount.AccountManager = termAM;
        TermAccount.AddressList = addressList;
        TermAccount.AccountName = acc.Name;
        TermAccount.TenPerEnrollIncreaseReduction=cas.Enrollment_Variation__c;
        if(acc.ParentId != Null){
        System.Debug('acc parentid***'+acc.ParentId);        
            TermAccount.ParentAccountID = acc.ParentId; //Added for PC-12835
            TermAccount.ParentName = [Select Id, Name From Account Where Id =: acc.ParentId].Name; //Added for PC-12835
        } 
        TermAccount.AccountNumber = acc.Account_Number__c;
        TermAccount.SitusState = acc.Situs_State__c;
        TermAccount.BidSpecification = acc.Bid_Specification__c;
        if(acc.NaicsCode != null){
            naicLst.add(new P2EwTermTransferPegaService.TermNAIC(acc.NaicsCode,acc.NaicsDesc));
            TermAccount.NAICList = naicLst;            
        }
        else{
            naicLst.add(new P2EwTermTransferPegaService.TermNAIC('unknown','unknown'));
            TermAccount.NAICList = naicLst;
        }
        List<P2EwTermTransferPegaService.GroupInfo> destGrpLst = new List<P2EwTermTransferPegaService.GroupInfo>();
        Map<Id,List<Segmentation__c>> mapCntrtSegLst1 = new Map<Id,List<Segmentation__c>>(); 
         //if((cas.Change_SubType__c=='Termination - Group' && cas.GroupTermJSON__c!=null) || ((cas.Change_SubType__c=='Term and Transfer - Group' || cas.Change_SubType__c=='Term and Transfer - Division') && cas.DestinationGrpJSON__c!=null))
        //if((cas.Change_SubType__c=='Termination - Group' && (cas.GroupDivisionJSON_0__c!=null || cas.GroupDivisionJSON_1__c!=null || cas.GroupDivisionJSON_2__c!=null || cas.GroupDivisionJSON_3__c!=null)) || ((cas.Change_SubType__c=='Term and Transfer - Group' || cas.Change_SubType__c=='Term and Transfer - Division') && cas.DestinationGrpJSON__c!=null))
        String destGrps;
        if(cas.Change_SubType__c=='Termination - Group'){
            //destGrps = cas.GroupTermJSON__c;
            destGrps=P2EhUtility.mergeJSON(cas);
        }
        if(cas.Change_SubType__c=='Term and Transfer - Group' || cas.Change_SubType__c=='Term and Transfer - Division'){
            destGrps = cas.DestinationGrpJSON__c;
        }
        if(destGrps!='' && (cas.Change_SubType__c=='Termination - Group' || cas.Change_SubType__c=='Term and Transfer - Group' || cas.Change_SubType__c=='Term and Transfer - Division')){
            List<Contract> srcCntrtLst = new List<Contract>();
            P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
            srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(destGrps,P2EwSrcContractwrapper.class);     
            srcCntrtLst=srcCntrtWrapper.srcCntrtList;
            set<Id> conIdSet = new set<Id>();            
            for(Contract con:srcCntrtLst){
                conIdSet.add(con.Id);                
            }
            List<Segmentation__c> segLst = [select id,name,Group_Number__c,status__c,Contract__c,MTV_DivisionNumber__c from Segmentation__c where Contract__c in:conIdSet AND Status__c='Activated'];
            for(Segmentation__c seg:segLst){
                if(mapCntrtSegLst1.get(seg.Contract__c)==null){
                    mapCntrtSegLst1.put(seg.Contract__c,new List<Segmentation__c>());
                }
                mapCntrtSegLst1.get(seg.Contract__c).add(seg);
            }
            for(Contract con:srcCntrtLst){
                P2EwTermTransferPegaService.GroupInfo destCntrt = new P2EwTermTransferPegaService.GroupInfo();
                List<P2EwTermTransferPegaService.DivisionInfo> destDivLst = new List<P2EwTermTransferPegaService.DivisionInfo>();
                destCntrt.GroupNumber = con.Group_Number__c;
                destCntrt.GroupName = con.Name;
                destCntrt.SoldPlanDesign = null;
                destCntrt.ProductName = con.Product_Name__c;
                destCntrt.GroupType = null;
                destCntrt.SubGroupType = null;
                destCntrt.ContractTermFrom = dateToStr(con.startdate);
                destCntrt.ContractTermTo = dateToStr(con.enddate);
                destCntrt.RenewalClause = String.valueOf(con.Renewal_clause__c);
                destCntrt.RenewalDate = dateToStr(con.Contractual_Renewal_Date__c);
                destCntrt.ContractTerm = Integer.valueOf(con.ContractTerm__c);
                destCntrt.UnderwrittenBy = con.Company_UW_the_Group__c;
                if(cas.Change_SubType__c=='Termination - Group'){             
                    destCntrt.IsGroupTerminate = true;
                }
                else{
                    destCntrt.IsGroupTerminate = false; 
                }               
                destCntrt.ContractId = con.Id;
                if(mapCntrtSegLst1.get(con.Id)!=null){
                    for(Segmentation__c seg:mapCntrtSegLst1.get(con.Id)){                        
                        P2EwTermTransferPegaService.DivisionInfo destDiv = new P2EwTermTransferPegaService.DivisionInfo();
                        destDiv.DivisionNumber=seg.MTV_DivisionNumber__c;
                        destDiv.DivisionName=seg.Name;
                        destDiv.DivisionId=seg.Id;
                        destDivLst.add(destDiv);
                    }
                }
                else{
                    destDivLst=new List<P2EwTermTransferPegaService.DivisionInfo>();
                }
                destCntrt.DivisionInfo=destDivLst; 
                destGrpLst.add(destCntrt);
            }                   
        }
        //if((cas.Change_SubType__c=='Termination - Division' && cas.DivisionTermJSON__c!=null) || (cas.Change_SubType__c=='Reinstatement' && cas.ReinsDivisionJSON__c!=null)){
        String srcDivs=P2EhUtility.mergeJSON(cas);
        if(srcDivs!='' && (cas.Change_SubType__c=='Termination - Division' || cas.Change_SubType__c=='Reinstatement')){
            /*String srcDivs;
            if(cas.Change_SubType__c=='Termination - Division' || cas.Change_SubType__c=='Reinstatement'){
                //srcDivs = cas.DivisionTermJSON__c;
                srcDivs=P2EhUtility.mergeJSON(cas);
            }*/
            /*if(cas.Change_SubType__c=='Reinstatement'){
                //srcDivs = cas.ReinsDivisionJSON__c;
                srcDivs=P2EhUtility.mergeJSON(cas); 
            }*/   
            List<Segmentation__c> srcSegLst = new List<Segmentation__c>();
            P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
            srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(srcDivs,P2EwSrcContractwrapper.class);     
            srcSegLst=srcCntrtWrapper.SourceDivisionList;
            system.debug('srcSegLst'+srcSegLst);
            for(Segmentation__c seg:srcSegLst){
                if(mapCntrtSegLst1.get(seg.Contract__c)==null){
                    mapCntrtSegLst1.put(seg.Contract__c,new List<Segmentation__c>());
                }
                mapCntrtSegLst1.get(seg.Contract__c).add(seg);
            }
            system.debug('mapCntrtSegLst1'+mapCntrtSegLst1);
            List<Contract> cntrtLst = [select id,name,Group_Number__c,Company_UW_the_Group__c,status,AccountId,startdate,enddate,Renewal_clause__c,Contractual_Renewal_Date__c,ContractTerm__c,Product_Name__c from contract where Id IN :mapCntrtSegLst1.keyset()];
            system.debug('cntrtLst'+cntrtLst);
            for(Contract con:cntrtLst){              
                P2EwTermTransferPegaService.GroupInfo destCntrt = new P2EwTermTransferPegaService.GroupInfo();
                List<P2EwTermTransferPegaService.DivisionInfo> destDivLst = new List<P2EwTermTransferPegaService.DivisionInfo>();
                destCntrt.GroupNumber = con.Group_Number__c;
                destCntrt.GroupName = con.Name;
                destCntrt.SoldPlanDesign = null;
                destCntrt.GroupType = null;
                destCntrt.SubGroupType = null;
                destCntrt.ProductName = con.Product_Name__c;
                destCntrt.ContractTermFrom = dateToStr(con.startdate);
                destCntrt.ContractTermTo = dateToStr(con.enddate);
                destCntrt.RenewalClause = String.valueOf(con.Renewal_clause__c);
                destCntrt.RenewalDate = dateToStr(con.Contractual_Renewal_Date__c);
                destCntrt.ContractTerm = Integer.valueOf(con.ContractTerm__c);
                destCntrt.UnderwrittenBy = con.Company_UW_the_Group__c;             
                destCntrt.IsGroupTerminate = false;                
                destCntrt.ContractId = con.Id;
                if(mapCntrtSegLst1.get(con.Id)!=null){
                    for(Segmentation__c seg:mapCntrtSegLst1.get(con.Id)){                        
                        P2EwTermTransferPegaService.DivisionInfo destDiv = new P2EwTermTransferPegaService.DivisionInfo();
                        destDiv.DivisionNumber=seg.MTV_DivisionNumber__c;
                        destDiv.DivisionName=seg.Name;
                        destDiv.DivisionId=seg.Id;
                        destDivLst.add(destDiv);
                    }
                }
                else{
                    destDivLst=new List<P2EwTermTransferPegaService.DivisionInfo>();
                }
                destCntrt.DivisionInfo=destDivLst; 
                destGrpLst.add(destCntrt);
            }
        }
        TermAccount.GroupInfo=destGrpLst;                           
        //Account - End :: RFIAccount
        P2EwTermTransferPegaService.TermCase TermCase = new P2EwTermTransferPegaService.TermCase();        
        TermCase.CaseID = cas.Id;
        TermCase.Subject = cas.Subject;
        TermCase.Description = cas.Description;
        TermCase.DueDate = dateToStr(cas.Due_Date__c);
        TermCase.Source = cas.Origin;
        //Opportunity - Start
        P2EwTermTransferPegaService.TermOpportunity TermOpportunity = new P2EwTermTransferPegaService.TermOpportunity();
        if(opp != null){
            TermOpportunity.SFDCCase=TermCase;
            TermOpportunity.OpportunityID = opp.Id;
            TermOpportunity.Amount = opp.Amount;
            TermOpportunity.Priority1 = opp.Priority_1__c;
            TermOpportunity.Priority2 = opp.Priority_2__c;
            TermOpportunity.Priority3 = opp.Priority_3__c;
            TermOpportunity.Priority4 = opp.Priority_4__c;
            TermOpportunity.Priority5 = opp.Priority_5__c;
            TermOpportunity.IsAutoRenewal = opp.AutoRenewal__c; 
            if(opp.Eligible_Primary_Enrollees__c!=null){
                TermOpportunity.TotalPrimaryEnrollees= integer.valueof(opp.Eligible_Primary_Enrollees__c);
            }
            TermOpportunity.EligiblePrimaryEnrollees = integer.valueOf(opp.No_of_Enrollees__c); 
            TermOpportunity.StrategicInfo = opp.Strategic_Pricing_Recommendations__c;
            List<OpportunityContactRole__c> OCRList;
            List<P2EwTermTransferPegaService.TTBroker> TTBrokers = new List<P2EwTermTransferPegaService.TTBroker>();
            try{
                OCRList = [select Id, Contact__r.AccountId, Contact__r.Account.Name, 
                    Contact__r.Account.Broker_Number__c, Contact__r.Account.BillingStreet, Contact__r.Account.BillingCity, 
                    Contact__r.Account.BillingState, Contact__r.Account.BillingCountry, Contact__r.Account.BillingPostalCode, 
                    Contact__r.Account.ShippingStreet, Contact__r.Account.ShippingCity, 
                    Contact__r.Account.ShippingState, Contact__r.Account.ShippingCountry, Contact__r.Account.ShippingPostalCode, 
                    Contact__r.Account.Phone, Contact__r.Account.Fax, Contact__r.Account.Company_Email__c, Contact__r.Account.RecordType.Name from OpportunityContactRole__c where 
                    Contact__r.Account.RecordType.Name = 'Producer Firm' and Opportunity__c =: opp.Id];
                
                for(OpportunityContactRole__c OCR : OCRList){
                    P2EwTermTransferPegaService.TTBroker TTBroker = new P2EwTermTransferPegaService.TTBroker();
                    TTBroker.BrokerID = OCR.Contact__r.Account.Broker_Number__c;
                    TTBroker.BrokerName = OCR.Contact__r.Account.Name;
                    TTBroker.Type = OCR.Contact__r.Account.RecordType.Name;
                    TTBroker.Commission = null;
                    //List<P2EwRFIPegaService.RFIAddressList> addressLst = new List<P2EwRFIPegaService.RFIAddressList>();
                    P2EwTermTransferPegaService.TermAddressList address = new P2EwTermTransferPegaService.TermAddressList(OCR.Contact__r.Account.BillingStreet, OCR.Contact__r.Account.BillingStreet, '', OCR.Contact__r.Account.BillingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(OCR.Contact__r.Account.BillingState), OCR.Contact__r.Account.BillingPostalCode, 'Shipping', true); // This is main address in UI
                    //addressLst.add(new P2EwRFIPegaService.RFIAddressList(OCR.Contact__r.Account.ShippingStreet, OCR.Contact__r.Account.ShippingStreet, '', OCR.Contact__r.Account.ShippingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, mapStateStateCode(OCR.Contact__r.Account.ShippingState), OCR.Contact__r.Account.ShippingPostalCode, 'Shipping', false));
                    TTBroker.Address = address;
                    TTBrokers.add(TTBroker);
                }
                TermOpportunity.Broker = TTBrokers;
            }catch(Exception e){
                TermOpportunity.Broker = null;
            }                 
        }else{
            TermOpportunity = null;
        }
        /*P2EwTermTransferPegaService.TermCase TermCase = new P2EwTermTransferPegaService.TermCase();        
        TermCase.CaseID = cas.Id;
        TermCase.Subject = cas.Subject;
        TermCase.Description = cas.Description;
        TermCase.DueDate = dateToStr(cas.Due_Date__c);
        TermCase.Source = cas.Origin;*/
        P2EwTermTransferPegaService.TermImplementation TermImplementation = new P2EwTermTransferPegaService.TermImplementation(TermOpportunity, TermAccount);//, TermCase);
        P2EwTermTransferPegaService.TermAndTransferNode ttnode;
        List<P2EwTermTransferPegaService.TermAndTransferNode> ttNodeLst = new List<P2EwTermTransferPegaService.TermAndTransferNode>();                        
        if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Group' || cas.Term_Transfer_Type__c=='Situs State Change - Region to Region'){
            Map<case,set<Id>> mapCasAcctIdSet = new Map<case,set<Id>>();
            Map<Id,List<Contract>> mapAcctCntrtLst = new Map<Id,List<Contract>>();
            Map<case,List<Account>> mapCasAcctLst = new Map<case,List<Account>>();
            Map<Case,Map<Id,List<Contract>>> mapCasMapAcctCntrtLst = new Map<Case,Map<Id,List<Contract>>>();
            String srcGrps = P2EhUtility.mergeJSON(cas);
            if(srcGrps!=''){
                //String srcGrps = cas.SrcGrpJSON__c;                
                List<Contract> srcCntrtLst = new List<Contract>();
                P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
                srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(srcGrps,P2EwSrcContractwrapper.class);     
                srcCntrtLst=srcCntrtWrapper.srcCntrtList;    
                for(Contract cnt:srcCntrtLst){
                    if(mapCasAcctIdSet.get(cas)==null){
                        mapCasAcctIdSet.put(cas,new set<Id>());
                    }
                    mapCasAcctIdSet.get(cas).add(cnt.AccountId);
                    
                    if(mapAcctCntrtLst.get(cnt.AccountId)==null){
                        mapAcctCntrtLst.put(cnt.AccountId,new List<contract>());
                    }
                    mapAcctCntrtLst.get(cnt.AccountId).add(cnt);
                }
                mapCasMapAcctCntrtLst.put(cas,mapAcctCntrtLst);
                String getqa = P2EhUtility.getQuery('Account');
                set<Id> accIdset = mapAcctCntrtLst.keyset();
                getqa = getqa + 'WHERE Id in:accIdset';                   
                List<Account> srcAccLst = Database.Query(getqa);
                for(Account acc:srcAccLst){
                    if(mapCasAcctIdSet.get(cas).contains(acc.Id)){
                        if(mapCasAcctLst.get(cas)==null){
                            mapCasAcctLst.put(cas, new List<Account>());
                        }
                        mapCasAcctLst.get(cas).add(acc);
                    }
                }
            }
            ttnode=frameTermTransfer(cas,mapCasAcctLst.get(cas),mapCasMapAcctCntrtLst.get(cas),null);
        }
        
        if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Division' || cas.Term_Transfer_Type__c=='Situs State Change - Within Region'){
            Map<case,set<Id>> mapCasCntrtIdSet = new Map<case,set<Id>>();
            Map<Id,List<Segmentation__c>> mapCntrtSegLst = new Map<Id,List<Segmentation__c>>();
            Map<Case,Map<Id,List<Segmentation__c>>> mapCasMapCntrtSegLst = new Map<Case,Map<Id,List<Segmentation__c>>>();
            Map<case,set<Id>> mapCasAcctIdSet = new Map<case,set<Id>>();
            Map<Id,List<Contract>> mapAcctCntrtLst = new Map<Id,List<Contract>>();
            Map<Case,Map<Id,List<Contract>>> mapCasMapAcctCntrtLst = new Map<Case,Map<Id,List<Contract>>>();
            Map<Case,List<Account>> mapCasAcctLst = new Map<Case,List<Account>>();
            //if(cas.SrcDivisionJSON__c!=null || cas.SrcDivisionJSON__c!=''){
            String srcDivs1=P2EhUtility.mergeJSON(cas);
            if(srcDivs1!=''){
                //String srcDivs = cas.SrcDivisionJSON__c;
                
                List<Segmentation__c> srcSegLst = new List<Segmentation__c>();
                P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
                srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(srcDivs,P2EwSrcContractwrapper.class);     
                srcSegLst=srcCntrtWrapper.SourceDivisionList;
                for(Segmentation__c seg:srcSegLst){
                    if(mapCasCntrtIdSet.get(cas)==null){   
                        mapCasCntrtIdSet.put(cas,new set<Id>());
                    }
                    mapCasCntrtIdSet.get(cas).add(seg.Contract__r.Id);
                    
                    if(mapCntrtSegLst.get(seg.Contract__r.Id)==null){
                        mapCntrtSegLst.put(seg.Contract__r.Id, new List<Segmentation__c>());
                    }
                    mapCntrtSegLst.get(seg.Contract__r.Id).add(seg);
                }
                mapCasMapCntrtSegLst.put(cas,mapCntrtSegLst);
                String getqc = P2EhUtility.getQuery('Contract');
                set<Id> cntrtIdset = mapCntrtSegLst.keyset();
                getqc = getqc + 'WHERE Id in:cntrtIdset';                   
                List<Contract> srcCntrtLst = Database.Query(getqc); 
                for(Contract cnt: srcCntrtLst){
                    if(mapCasCntrtIdSet.get(cas).contains(cnt.Id)){
                        if(mapAcctCntrtLst.get(cnt.AccountId)==null){
                            mapAcctCntrtLst.put(cnt.AccountId, new List<Contract>());
                        }
                        mapAcctCntrtLst.get(cnt.AccountId).add(cnt);
                        if(mapCasAcctIdSet.get(cas)==null){
                            mapCasAcctIdSet.put(cas,new set<Id>());
                        }
                        mapCasAcctIdSet.get(cas).add(cnt.AccountId);
                    }
                    
                }
                mapCasMapAcctCntrtLst.put(cas,mapAcctCntrtLst); 
                String getqa = P2EhUtility.getQuery('Account');
                set<Id> accntIdset = mapAcctCntrtLst.keyset();
                getqa = getqa + 'WHERE Id in:accntIdset';                   
                List<Account> srcAccLst = Database.Query(getqa);
                for(Account acc:srcAccLst){
                    if(mapCasAcctIdSet.get(cas).contains(acc.Id)){
                        if(mapCasAcctLst.get(cas)==null){
                            mapCasAcctLst.put(cas, new List<Account>());
                        }
                        mapCasAcctLst.get(cas).add(acc);
                    }
                }     
            }
            ttnode=frameTermTransfer(cas,mapCasAcctLst.get(cas),mapCasMapAcctCntrtLst.get(cas),mapCasMapCntrtSegLst.get(cas));         
        }
        ttNodeLst.add(ttnode);
        TermImplementation.TermAndTransfer=ttNodeLst;                        
        TTReq = new P2EwTermTransferRequest();
        TTReq.ServiceType = 'ChangeRequest';
        TTReq.ChangeType = 'NonRate';
        if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Group' || cas.Term_Transfer_Type__c=='Situs State Change - Region to Region'){        
            TTReq.ChangeSubType = 'TermAndTransfer-Group';
        }
        if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Division' || cas.Term_Transfer_Type__c=='Situs State Change - Within Region'){ 
            TTReq.ChangeSubType = 'TermAndTransfer-Division';
        }
        if(cas.Change_SubType__c=='Termination - Group'){
            TTReq.ChangeSubType = 'Termination-Group';
        }
        if(cas.Change_SubType__c=='Termination - Division'){
            TTReq.ChangeSubType = 'Termination-Division';
        }
        if(cas.Change_SubType__c=='Reinstatement'){
            TTReq.ChangeSubType = 'Reinstatement';
        }
        if(cas.Change_SubType__c=='Termination - Group' || cas.Change_SubType__c=='Termination - Division' || cas.Change_SubType__c=='Reinstatement'){
            TTReq.Notes=cas.Notes_for_IM__c;
            //TTReq.EffectiveDate=dateToStr(cas.Due_Date__c);
            TermImplementation.TermAndTransfer=new List<P2EwTermTransferPegaService.TermAndTransferNode>();
        }
        TTReq.EffectiveDate=dateToStr(cas.Due_Date__c); 
        TTReq.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604        
        TTReq.Implementation = TermImplementation;               
        if(!Test.isRunningTest()){
            httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, TTReq.generate(),'Pega',username,'getTermTransfer');
        }else{
            //httpRespBody = '{"Proposal":{"CaseStatus":"Pending-Review","CaseID":"G-2470"}}';   
            httpRespBody =  '{"Implementation":{"CaseStatus":"New","CaseID":"CR-27306"}}';
        }
               
        //Frame Response
        if(httpRespBody!=null){
            try{
                ttResp = P2EwTermTransferResponse.parse(httpRespBody);
                String validateRespStr = ttResp.validateResponse();
                
                if(ttResp.Implementation.Error!=null && ttResp.Implementation.Error.ErrorMessage!=null){
                    /*system.debug('ErrorMessage:::'+ttResp.Implementation.Error.ErrorMessage);
                    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,ttResp.Implementation.Error.ErrorMessage);
                    ApexPages.addMessage(myMsg);*/
                    throw new P2EException('P2EhPegaCallouts - getTermTransfer()',ttResp.Implementation.Error.ErrorMessage,'','Manual');
                }else if(validateRespStr != null){
                    /*system.debug('Valida:::::::'+validateRespStr);
                    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,validateRespStr);
                    ApexPages.addMessage(myMsg);*/
                    throw new P2EException('P2EhPegaCallouts - getTermTransfer()',validateRespStr,'','Manual');
                }
            }catch(JSONException e){
                
            }catch(Exception e){
                throw e;                        
            }
            Id TTGrpSubmitted =P2EhUtility.getRecordTypeId('case','TT Group Submitted');
            Id TTDivSubmitted =P2EhUtility.getRecordTypeId('case','TT Division Submitted');
            Id TermSubmitted =P2EhUtility.getRecordTypeId('case','Termination Submitted');
            Id ReinSubmitted =P2EhUtility.getRecordTypeId('case','Rein Submitted');
            if(ttResp.Implementation !=null && ttResp.Implementation.CaseID!=null && ttResp.Implementation.CaseID!=''){
                if(cas.Change_SubType__c=='Termination - Group' || cas.Change_SubType__c=='Termination - Division'){
                    this.cas.RecordTypeId = TermSubmitted;
                }
                if(cas.Change_SubType__c=='Term and Transfer - Group'){
                    this.cas.RecordTypeId = TTGrpSubmitted;
                }
                if(cas.Change_SubType__c=='Term and Transfer - Division'){
                    this.cas.RecordTypeId = TTDivSubmitted;
                }
                if(cas.Change_SubType__c=='Reinstatement'){
                    this.cas.RecordTypeId = ReinSubmitted;
                }    
                this.cas.UW_Case_ID__c = ttResp.Implementation.CaseID;
                this.cas.Status = ttResp.Implementation.CaseStatus;
                update cas;
            }
        }
    }
    
    private P2EwTermTransferPegaService.TermAndTransferNode frameTermTransfer(Case ttCase,List<Account> accLst,Map<Id,List<Contract>> mapAcctCntrtLst,Map<Id,List<Segmentation__c>> mapCntrtSegLst){
        Map<Id,User> mapAccAccExc = new Map<Id,User>();
        Map<Id,User> mapAccAccMgr = new Map<Id,User>();
        Map<Id,Account> mapAccParAcc = new Map<Id,Account>();
        set<Id> setAccExcId = new set<Id>();
        set<Id> setAccMgrId = new set<Id>();
        set<Id> setParAccId = new set<Id>();
        List<String> grpNumLst = new List<String>();
        List<String> divNumLst = new List<String>();
        String separator = ','; 
        P2EwTermTransferPegaService.TermAndTransferNode ttnode = new P2EwTermTransferPegaService.TermAndTransferNode();
        List<P2EwTermTransferPegaService.SourceAcctInfoNode> srcAccountLst = new List<P2EwTermTransferPegaService.SourceAcctInfoNode>();      
        ttnode.TermTransferType=ttCase.Term_Transfer_Type__c;
        ttnode.TermTransferSubType=ttCase.Term_Transfer_Sub_Type__c; 
        ttnode.NewDivBenefits=ttCase.New_Division_Benefits__c;
        ttnode.NewDivNumbers=ttCase.New_Division_Numbers__c;
        ttnode.NewDivNames=ttCase.New_Division_Names__c;
        ttnode.IMNotes=ttCase.Notes_for_IM__c;
        ttnode.Approvals=ttCase.Approvals_Needed__c;
        ttnode.BillContactMail=ttCase.Billing_Contact_Email__c;
        ttnode.BillContactName=ttCase.Billing_Contact_Name__c;
        ttnode.BillContactPhone=ttCase.Billing_Contact_Ph__c;
        ttnode.BillRollUpId=ttCase.Billing_Roll_Up_ID__c;
        ttnode.DivContactMail=ttCase.Division_Contact_Email__c;
        ttnode.DivContactName=ttCase.Division_Contact_Name__c;
        ttnode.DivContactPhone=ttCase.Division_Contact_Phone__c;
        ttnode.DivType=ttCase.Division_Type__c;
        ttnode.EnrollEffDate=dateToStr(ttCase.Effective_Date_for_Enrollees__c);
        ttnode.DivEffTermDate=dateToStr(ttCase.Effective_Date_of_Division_term__c);
        ttnode.GrpEffTermDate=dateToStr(ttCase.Effective_Date_of_Group_Term__c);
        ttnode.NewDivsEffDate=dateToStr(ttCase.Effective_Date_of_new_Division__c);
        ttnode.EMAOBRInfo=ttCase.EMA_OBR_Info__c;
        ttnode.EnrollTransferTo=ttCase.Enrollment_Transferring_to__c;
        ttnode.EnrollTransferType=ttCase.Enrollment_Transferring_Type__c; 
        for(Account acct:accLst){
            if(acct.Account_Executive__c!=null){
                setAccExcId.add(acct.Account_Executive__c);
            }
            if(acct.Account_Manager__c!=null){
                setAccMgrId.add(acct.Account_Manager__c);
            }
            if(acct.ParentId!=null){
                setParAccId.add(acct.ParentId);
            }       
        }
        List<User> accExcList;
        List<User> accMgrList;
        List<Account> parAcctLst;
        if(setAccExcId!=null){
            accExcList = [Select Id, Name, Email, Username From User Where Id in:setAccExcId];
        }
        if(setAccMgrId!=null){
            accMgrList = [Select Id, Name, Email, Username From User Where Id in:setAccMgrId];
        }
        if(setParAccId!=null){
            parAcctLst = [select Id, Name from Account where Id in:setParAccId];
        }
        for(Account acct:accLst){
            List<P2EwTermTransferPegaService.GroupInfo> srcGrpLst = new List<P2EwTermTransferPegaService.GroupInfo>();
            if(accExcList!=null){            
                for(User ae:accExcList){
                    if(acct.Account_Executive__c==ae.Id){
                        mapAccAccExc.put(acct.Id,ae);
                    }
                }
            }
            if(accMgrList!=null){            
                for(User am:accMgrList){
                    if(acct.Account_Manager__c==am.Id){
                        mapAccAccMgr.put(acct.Id,am);
                    }
                }
            }
            if(parAcctLst!=null){            
                for(Account parAcct:parAcctLst){
                    if(acct.ParentId==parAcct.Id){
                        mapAccParAcc.put(acct.Id,parAcct);
                    }
                }
            }
            List<P2EwTermTransferPegaService.TermAddressList> addressList;
            P2EwTermTransferPegaService.TermAccountExecutive termAE;
            P2EwTermTransferPegaService.TermAccountManager termAM;
            User ae;
            try{
                addressList = new List<P2EwTermTransferPegaService.TermAddressList>();
                addressList.add(new P2EwTermTransferPegaService.TermAddressList(acc.BillingStreet, acc.BillingStreet, '', acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, 'Shipping', true)); //This is main address in UI
                addressList.add(new P2EwTermTransferPegaService.TermAddressList(acc.ShippingStreet, acc.ShippingStreet, '', acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, 'Billing', false));//This is Billing address in UI
                
                try{
                    if(mapAccAccExc.keyset().contains(acct.Id)){
                        ae=mapAccAccExc.get(acct.Id);
                    }    //ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
                }
                catch(Exception exp){
                    ae = null;
                }
                if(ae!=null){
                    termAE= new P2EwTermTransferPegaService.TermAccountExecutive(ae.Name, ae.Email);
                    termAE.ExternalID = ae.Username;
                    termAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
                }
                else{
                    termAE = new P2EwTermTransferPegaService.TermAccountExecutive('No AE assigned','');
                }
                User am;
                try{
                    if(mapAccAccMgr.keyset().contains(acct.Id)){
                        am=mapAccAccMgr.get(acct.Id);
                    }
                    //am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
                }
                catch(Exception exp){
                    am = null;
                }
                if(am!=null){
                    termAM= new P2EwTermTransferPegaService.TermAccountManager(am.Name, am.Email);
                    termAM.ExternalID = am.Username;
                    termAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
                }
                else{
                    termAM= new P2EwTermTransferPegaService.TermAccountManager ('No AM assigned','');
                }
            }catch(Exception e){
                
                //return null;
            }             
            List<P2EwTermTransferPegaService.TermNAIC> naicLst = new List<P2EwTermTransferPegaService.TermNAIC>();
            P2EwTermTransferPegaService.SourceAcctInfoNode srcAccount = new P2EwTermTransferPegaService.SourceAcctInfoNode();
            srcAccount.AccountID = acct.Id;
            srcAccount.NumberOfEmployees = acct.NumberOfEmployees;
            srcAccount.AccountExecutive = termAE;
            srcAccount.AccountManager = termAM;
            srcAccount.AddressList = addressList;
            srcAccount.AccountName = acct.Name;
            if(mapAccParAcc.keyset().contains(acct.Id)){
            //System.Debug('acc parentid***'+acc.ParentId);        
                srcAccount.ParentAccountID = mapAccParAcc.get(acct.Id).Id; //Added for PC-12835
                srcAccount.ParentName = mapAccParAcc.get(acct.Id).Name; //Added for PC-12835
            } 
            srcAccount.AccountNumber = acct.Account_Number__c;
            srcAccount.SitusState = acct.Situs_State__c;
            srcAccount.BidSpecification = acct.Bid_Specification__c;
            if(acct.NaicsCode != null){
                naicLst.add(new P2EwTermTransferPegaService.TermNAIC(acct.NaicsCode,acct.NaicsDesc));
                srcAccount.NAICList = naicLst;            
            }
            else{
                naicLst.add(new P2EwTermTransferPegaService.TermNAIC('unknown','unknown'));
                srcAccount.NAICList = naicLst;
            }            
            for(Contract con:mapAcctCntrtLst.get(acct.Id)){
                if(con.Group_Number__c!=null){
                    grpNumLst.add(con.Group_Number__c);
                }
                P2EwTermTransferPegaService.GroupInfo srcCntrt = new P2EwTermTransferPegaService.GroupInfo();
                List<P2EwTermTransferPegaService.DivisionInfo> srcDivLst = new List<P2EwTermTransferPegaService.DivisionInfo>();
                srcCntrt.GroupNumber = con.Group_Number__c;
                srcCntrt.GroupName = con.Name;
                srcCntrt.SoldPlanDesign = null;
                srcCntrt.GroupType = null;
                srcCntrt.SubGroupType = null;
                srcCntrt.ProductName = con.Product_Name__c;
                srcCntrt.ContractTermFrom = dateToStr(con.startdate);
                srcCntrt.ContractTermTo = dateToStr(con.enddate);
                srcCntrt.RenewalClause = String.valueOf(con.Renewal_clause__c);
                srcCntrt.RenewalDate = dateToStr(con.Contractual_Renewal_Date__c);
                srcCntrt.ContractTerm = Integer.valueOf(con.ContractTerm__c);
                srcCntrt.UnderwrittenBy = con.Company_UW_the_Group__c;
                if(mapCntrtSegLst==null){
                    srcCntrt.IsGroupTerminate = true;
                }
                else{
                    srcCntrt.IsGroupTerminate = false;
                }
                srcCntrt.ContractId = con.Id;                
                if(mapCntrtSegLst!=null){
                    for(Segmentation__c seg:mapCntrtSegLst.get(con.Id)){
                        if(seg.MTV_DivisionNumber__c!=null){
                            divNumLst.add(seg.MTV_DivisionNumber__c);
                        }
                        P2EwTermTransferPegaService.DivisionInfo srcDiv = new P2EwTermTransferPegaService.DivisionInfo();
                        srcDiv.DivisionNumber=seg.MTV_DivisionNumber__c;
                        srcDiv.DivisionName=seg.Name;
                        srcDiv.DivisionId=seg.Id;
                        srcDivLst.add(srcDiv);
                    }
                    srcCntrt.DivisionInfo=srcDivLst;
                }
                else{
                    srcCntrt.DivisionInfo=new List<P2EwTermTransferPegaService.DivisionInfo>();
                }                       
                srcGrpLst.add(srcCntrt);
            }
            srcAccount.GroupInfo=srcGrpLst;
            srcAccountLst.add(srcAccount);               
        }
        if(mapCntrtSegLst==null){
            ttnode.TermingGroup = String.join(grpNumLst,separator);
            ttnode.TermingDivision=null;
        }
        else{
            ttnode.TermingGroup =null;
            ttnode.TermingDivision=String.join(divNumLst,separator);
        }
        if((ttCase.Term_Transfer_Sub_Type__c!=null && (ttCase.Term_Transfer_Sub_Type__c=='Term one Group into New Division(s)' || ttCase.Term_Transfer_Sub_Type__c=='Term from one Division into a New Division')) || ttCase.Term_Transfer_Type__c=='Situs State Change - Within Region'){
            ttnode.AddADivsion = true;
        }
        else{
            ttnode.AddADivsion = false;
        }    
        ttnode.SourceAcctInfo=srcAccountLst;
        return ttnode;               
    }//Term and Transfer Code by Geetha END
    public Object getOSRRate(String reqName){
        P2EwQQRequest qqReq;
        P2EwRFPRequest rfpReq;
        P2EwImplRequest implReq;
        Map<id,Set<id>> mapProdWithSeg = new Map<id,Set<id>>();// updated by Geetha for PC-13347 on 9/30/16
        Map<id,Set<id>> mapRatesheetWithSeg = new Map<id,Set<id>>();// updated by Geetha for PC-13347 on 9/30/16
        Map<Id,Segmentation__c> segList = new Map<Id,Segmentation__c>();// updated by Geetha for PC-13347 on 9/30/16
        /* Contact - Start */
        List<P2EwPegaService.QQContacts> qqCon = framePegaContact();
        /* Contact - End */
        
        /* Account - Start */
        P2EwPegaService.QQQAccount qqAccount = framePegaAccount();
        List<P2EwPegaService.QQGroupInfo> GroupInfoList;
        if(reqName.equals('Renewal') || reqName.equals('Change') || (reqName.equals('IMPL'))){
            qqAccount.GroupInfo = frameGroupInfo('Opportunity');
        }else{
            qqAccount.GroupInfo = null;
        }
        
        if(reqName == 'IMPL' || (reqName.equals('Renewal')) || (reqName.equals('Change')) ){
            if(qqAccount.SitusState != null){
                qqAccount.SitusState = qqAccount.SitusState;
            }
        }
        
        /* Account - End */
        
        /* Opportunity - Start */
        List<Case> casLst;
        String getqc = P2EhUtility.getQuery('Case');
        String st='Resolved-Completed';
       // system.debug('quoteid'+quot.Id);
        if(reqName=='IMPL'){
            if(opp.type!='Change'){
                getqc = getqc + 'WHERE Related_opportunity__c=\''+opp.Id+'\' AND Term_Transfer_Type__c!=null AND status!=\''+st+'\' AND Term_And_Transfer__c=true AND Change_Type__c=null AND Change_SubType__c=null';
            }
            else{
                String chtype='Rate Impacting Changes';
                getqc = getqc + 'WHERE Related_opportunity__c=\''+opp.Id+'\' AND Term_Transfer_Type__c!=null AND status!=\''+st+'\' AND Term_And_Transfer__c=true AND ((Change_Type__c=null AND Change_SubType__c=null) OR (Change_Type__c=\''+chtype+'\'))';
            }   
        }
        else{
            getqc = getqc + 'WHERE Quote__c =\''+quot.Id+'\' AND Term_Transfer_Type__c!=null AND status!=\''+st+'\' AND Enrollment_Variation__c=true';
        }
        System.debug(getqc);
        
        try{
                
                casLst = Database.Query(getqc);
                System.debug('termandtransfercase'+casLst);
        }
        catch(Exception exp){
                casLst = null;
        }
        if(casLst!=null){
            for(Case cs:casLst){            
                qqAccount.TenPerEnrollIncreaseReduction=cs.Enrollment_Variation__c;
                break;
            }
        }    
        System.debug('termandtransfercase'+cas);
        P2EwTermTransferPegaService.TermAndTransferNode ttnode;
        List<P2EwTermTransferPegaService.TermAndTransferNode> ttNodeLst = new List<P2EwTermTransferPegaService.TermAndTransferNode>();
        List<Case> grpCasLst = new List<Case>();
        List<Case> divCasLst = new List<Case>();
        if(casLst!=null){
            for(Case cas:casLst){
                if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Group' || cas.Term_Transfer_Type__c=='Situs State Change - Region to Region'){
                    grpCasLst.add(cas);
                }
                if(cas.Term_Transfer_Type__c=='Non Situs State Change - Term And Transfer Division' || cas.Term_Transfer_Type__c=='Situs State Change - Within Region'){
                    divCasLst.add(cas);
                }
            }
            
            //Group Cases
            Map<Case,Map<Id,List<Contract>>> mapCasMapAcctCntrtLst = new Map<Case,Map<Id,List<Contract>>>();
            Map<case,set<Id>> mapCasAcctIdSet = new Map<case,set<Id>>();
            set<Id> allAcctId = new set<Id>();
            for(Case cas:grpCasLst){                
                Map<Id,List<Contract>> mapAcctCntrtLst = new Map<Id,List<Contract>>();
                //Map<case,List<Account>> mapCasAcctLst = new Map<case,List<Account>>();
                String srcGrps = P2EhUtility.mergeJSON(cas);                
                if(srcGrps!=''){
                    //String srcGrps = cas.SrcGrpJSON__c;                    
                    List<Contract> srcCntrtLst = new List<Contract>();
                    P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
                    srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(srcGrps,P2EwSrcContractwrapper.class);     
                    srcCntrtLst=srcCntrtWrapper.srcCntrtList;    
                    for(Contract cnt:srcCntrtLst){
                        if(mapCasAcctIdSet.get(cas)==null){
                            mapCasAcctIdSet.put(cas,new set<Id>());
                        }
                        mapCasAcctIdSet.get(cas).add(cnt.AccountId);
                        
                        if(mapAcctCntrtLst.get(cnt.AccountId)==null){
                            mapAcctCntrtLst.put(cnt.AccountId,new List<contract>());
                        }
                        mapAcctCntrtLst.get(cnt.AccountId).add(cnt);
                    }
                    allAcctId.addAll(mapAcctCntrtLst.keyset());
                    mapCasMapAcctCntrtLst.put(cas,mapAcctCntrtLst);
                }
            }
                    
            String getqa = P2EhUtility.getQuery('Account');
            //set<Id> accIdset1 = mapAcctCntrtLst.keyset();
            getqa = getqa + 'WHERE Id in:allAcctId';                   
            List<Account> srcAccLst = Database.Query(getqa);
            Map<case,List<Account>> mapCasAcctLst = new Map<case,List<Account>>();
            for(Case cas:grpCasLst){
                for(Account acc:srcAccLst){
                    if(mapCasAcctIdSet.get(cas).contains(acc.Id)){
                        if(mapCasAcctLst.get(cas)==null){
                            mapCasAcctLst.put(cas, new List<Account>());
                        }
                        mapCasAcctLst.get(cas).add(acc);
                    }
                }
                if(mapCasAcctLst.get(cas)!=null && mapCasMapAcctCntrtLst.get(cas)!=null){
                    ttnode=frameTermTransfer(cas,mapCasAcctLst.get(cas),mapCasMapAcctCntrtLst.get(cas),null);                
                    ttNodeLst.add(ttnode);
                }
            }
            
            //Group Cases
            
            //Division Cases
            Map<case,set<Id>> mapCasCntrtIdSet = new Map<case,set<Id>>();
            Map<Case,Map<Id,List<Segmentation__c>>> mapCasMapCntrtSegLst = new Map<Case,Map<Id,List<Segmentation__c>>>();
            set<Id> allCntrtId = new set<Id>();
            for(Case cas:divCasLst){                
                Map<Id,List<Segmentation__c>> mapCntrtSegLst = new Map<Id,List<Segmentation__c>>();                
                //Map<case,set<Id>> mapCasAcctIdSet = new Map<case,set<Id>>();
                //Map<Id,List<Contract>> mapAcctCntrtLst = new Map<Id,List<Contract>>();
                //Map<Case,Map<Id,List<Contract>>> mapCasMapAcctCntrtLst = new Map<Case,Map<Id,List<Contract>>>();
                //Map<Case,List<Account>> mapCasAcctLst = new Map<Case,List<Account>>();
                //if(cas.SrcDivisionJSON__c!=null || cas.SrcDivisionJSON__c!=''){
                String srcDivs=P2EhUtility.mergeJSON(cas);
                if(srcDivs!=''){
                    //String srcDivs = cas.SrcDivisionJSON__c;
                    
                    List<Segmentation__c> srcSegLst = new List<Segmentation__c>();
                    P2EwSrcContractwrapper srcCntrtWrapper = new P2EwSrcContractwrapper();
                    srcCntrtWrapper=(P2EwSrcContractwrapper)System.JSON.deserialize(srcDivs,P2EwSrcContractwrapper.class);     
                    srcSegLst=srcCntrtWrapper.SourceDivisionList;
                    for(Segmentation__c seg:srcSegLst){
                        if(mapCasCntrtIdSet.get(cas)==null){   
                            mapCasCntrtIdSet.put(cas,new set<Id>());
                        }
                        mapCasCntrtIdSet.get(cas).add(seg.Contract__r.Id);
                        
                        if(mapCntrtSegLst.get(seg.Contract__r.Id)==null){
                            mapCntrtSegLst.put(seg.Contract__r.Id, new List<Segmentation__c>());
                        }
                        mapCntrtSegLst.get(seg.Contract__r.Id).add(seg);
                    }
                    allCntrtId.addAll(mapCntrtSegLst.keyset());
                    mapCasMapCntrtSegLst.put(cas,mapCntrtSegLst);                    
                }                
            }
            String getqc1 = P2EhUtility.getQuery('Contract');
            //set<Id> cntrtIdset1 = mapAcctCntrtLst.keyset();
            getqc1 = getqc1 + 'WHERE Id in:allCntrtId';                   
            List<Contract> srcCntrtLst1 = Database.Query(getqc1);
            Map<Case,Map<Id,List<Contract>>> mapCasMapAcctCntrtLst1 = new Map<Case,Map<Id,List<Contract>>>();
            Map<case,set<Id>> mapCasAcctIdSet1 = new Map<case,set<Id>>();
            set<Id> allAccId1 = new set<Id>(); 
            for(Case cas:divCasLst){
                Map<Id,List<Contract>> mapAcctCntrtLst1 = new Map<Id,List<Contract>>();
                for(Contract cnt: srcCntrtLst1){                    
                    if(mapCasCntrtIdSet.get(cas).contains(cnt.Id)){
                        if(mapAcctCntrtLst1.get(cnt.AccountId)==null){
                            mapAcctCntrtLst1.put(cnt.AccountId, new List<Contract>());
                        }
                        mapAcctCntrtLst1.get(cnt.AccountId).add(cnt);
                        if(mapCasAcctIdSet1.get(cas)==null){
                            mapCasAcctIdSet1.put(cas,new set<Id>());
                        }
                        mapCasAcctIdSet1.get(cas).add(cnt.AccountId);
                    }                    
                }
                allAccId1.addAll(mapAcctCntrtLst1.keyset());
                mapCasMapAcctCntrtLst1.put(cas,mapAcctCntrtLst1); 
            }            
            String getqa1 = P2EhUtility.getQuery('Account');
            //set<Id> accountIdset = mapAcctCntrtLst.keyset();
            getqa1 = getqa1 + 'WHERE Id in:allAccId1';                   
            List<Account> srcAccLst1 = Database.Query(getqa1);
            Map<Case,List<Account>> mapCasAcctLst1 = new Map<Case,List<Account>>();
            for(Case cas:divCasLst){
                for(Account acc:srcAccLst1){
                    if(mapCasAcctIdSet1.get(cas).contains(acc.Id)){
                        if(mapCasAcctLst1.get(cas)==null){
                            mapCasAcctLst1.put(cas, new List<Account>());
                        }
                        mapCasAcctLst1.get(cas).add(acc);
                    }
                }
                if(mapCasAcctLst1.get(cas)!=null && mapCasMapAcctCntrtLst1.get(cas)!=null && mapCasMapCntrtSegLst.get(cas)!=null){
                    ttnode=frameTermTransfer(cas,mapCasAcctLst1.get(cas),mapCasMapAcctCntrtLst1.get(cas),mapCasMapCntrtSegLst.get(cas));
                    ttNodeLst.add(ttnode); 
                }     
            }
            //Division Cases
            
            //ttNodeLst.add(ttnode);
        }
        else{
            ttNodeLst = new List<P2EwTermTransferPegaService.TermAndTransferNode>();
        }
        P2EwPegaService.QQOpportunity qqOpportunity = framePegaOpportunity();
        if(reqName == 'IMPL'){
            if(opp.Sales_Notes_for_Implementation__c != Null){
                qqOpportunity.SalesNotes = EncodingUtil.base64Encode(Blob.valueOf(opp.Sales_Notes_for_Implementation__c));
                qqOpportunity.SalesNotesList = new List<P2EwPegaService.QQNotes>{new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(opp.Sales_Notes_for_Implementation__c)))};
            } 
        }
        //RFPType
        if(ReqName == 'Renewal'){
            qqOpportunity.RFPType = 'Renewal with change';
        }else if(ReqName == 'Change'){
            qqOpportunity.RFPType = 'Change';
        }
        //EligiblePrimaryEnrollees
        
        qqOpportunity.EligiblePrimaryEnrollees = integer.valueOf(opp.No_of_Enrollees__c);
        qqOpportunity.TotalPrimaryEnrollees    = integer.valueOf(opp.Eligible_Primary_Enrollees__c);
        qqOpportunity.CurrentFFSSubscribers    = integer.valueOf(opp.FFS_Number_of_Current_Primary_Enrollees__c);  //Added for Lives Change
        qqOpportunity.CurrentDHMOSubscribers   = integer.valueOf(opp.DHMO_Number_of_Current_Primary_Enrollees__c); //Added for Lives Change
        
        /* Commented as per PC-8420
        if(reqName.equals('New')|| reqName.equals('RFP') || (opp.Type == 'New' && reqName.equals('IMPL'))){
            qqOpportunity.EligiblePrimaryEnrollees = integer.valueOf(opp.Eligible_Primary_Enrollees__c);
        }else if(reqName.equals('Renewal') || reqName.equals('Change') || (reqName.equals('IMPL') && opp.Type == 'Renewal') || (reqName.equals('IMPL') && opp.Type == 'Change')){
            qqOpportunity.EligiblePrimaryEnrollees = integer.valueOf(opp.Current_Delta_Primary_Enrollees__c); 
        }
        */
        //Survey
        if(opp.Type == 'Renewal' && opp.AutoRenewal__c == false && opp.Contract_End_Date__c > system.Today()){
            P2EwPegaService.QQEarlyRenewalSurvey SurveyItem = new P2EwPegaService.QQEarlyRenewalSurvey();
            SurveyItem.ReasonForEarlyRenewal = opp.Reason_for_early_renewal__c;
            if(opp.Reason_for_early_renewal__c=='Others'){
                SurveyItem.ReasonForRequest = opp.Reason_for_Request__c;    
            }
            if(quot!=null){            
                SurveyItem.DueDate = quot.Date_Requested_by_AE__c;
            }
            SurveyItem.AlternativesNeeded = opp.Alternatives_needed__c;
            SurveyItem.UpdateRenewalClause = opp.Update_renewal_clause__c;
            SurveyItem.OpenService = opp.Open_service__c;
            SurveyItem.SensitiveIssues = opp.Sensitive_issues__c;
            SurveyItem.DeltaPositionedNeutralOrCompetitive = opp.Delta_positioned_neutral_competitve__c;
            SurveyItem.AcquisitionsOrNewGroupGrowing = opp.Acquisitions_or_new_group_growing__c;
            SurveyItem.CompetitiveConsiderations = opp.Competitive_considerations__c;
            qqOpportunity.Survey = SurveyItem;
        }else{
            qqOpportunity.Survey = null;
        }
        
        //****PC-15314 - Added below new field to PEGA
        qqOpportunity.IsSpecialAutoRenewal = false;
        if(opp.Type == 'Renewal'){
            qqOpportunity.IsSpecialAutoRenewal = opp.Special_Auto_Renewal__c;
        }
        
        P2EwPegaService.QQSFDCCase qqSFDCc = new P2EwPegaService.QQSFDCCase();
        System.debug('CASE ID**' + cas);
        if(cas!=null){
            qqSFDCc.CaseID = String.valueOf(cas.id);
        }
        qqOpportunity.SFDCCase = qqSFDCc;
        /* Opportunity - End */
        
        String chngeOppChangeType = null;
        if(opp.Type=='Change'){
            try{
                //chngeOppChangeType = [select case__r.Change_SubType__c, Type from Opportunity where id =: opp.Id].case__r.Change_SubType__c;
                //chngeOppChangeType = [select id,Change_SubType__c from case where ChangeOpportunity__c =: opp.Id].Change_SubType__c; 
                
                chngeOppChangeType = [select id,Change_Subtype__c from opportunity where id =: opp.Id].Change_Subtype__c ;                
                System.debug('chngeOppChangeType **' + chngeOppChangeType );
                qqOpportunity.RateChangeType = chngeOppChangeType;
            }catch(Exception e){
                system.debug('chngeOppChangeType :: ' + chngeOppChangeType);
            }
        }
        
        /* Plans - Start */
        List<P2EwPegaService.QQPlans> plansList = new List<P2EwPegaService.QQPlans>();
        Map<id,List<ProdBenefit__c>> mapPrdIdPrdBen = new Map<id,List<ProdBenefit__c>>();//Geetha PC-15498
        //if(!P2EhGlobalUtil.isAutoRFP){
            Map<String, String> qqPlansStrMap = new Map<String, String>();
            
            List<PegaPlansCache__c> ppCacheLst;
            system.debug('cache.allPlanIds***'+cache);
            
            Set<Id> pIds = new Set<Id>();
            if(reqName != 'IMPL'){
                for(String planId : cache.allPlanIds){
                    pIds.add(cache.allPlansMap.get(planId).productId);
                }
                ppCacheLst = Database.Query(P2EhUtility.getQuery('PegaPlansCache__c') + ' where Product__c in: pIds order by PartNumber__c ASC'); //Quote__c =: quotId and 
            }else{
                ppCacheLst = Database.Query(P2EhUtility.getQuery('PegaPlansCache__c') + ' where Product__c in: prodIds order by PartNumber__c ASC');
                List<ProdBenefit__c> ProdBenefitLst= [SELECT ID,Name,Benefit_Package__c,Benefit_Package_ID__c,Product__c FROM ProdBenefit__c WHERE Product__c in:prodIds];//Geetha PC-15498 
                for(ProdBenefit__c prdBen:ProdBenefitLst){
                    if(mapPrdIdPrdBen.get(prdBen.Product__c)==null){
                       mapPrdIdPrdBen.put(prdBen.Product__c,new List<ProdBenefit__c>());
                    }
                    mapPrdIdPrdBen.get(prdBen.Product__c).add(prdBen);
                } //Geetha code End for PC-15498
            }
            
            /****HCL::START Get Benefit Packages from BenefitPackage Object*****/
            Map<String,String> mapPlan_Benefit = new Map<String,String>();
            if(!ppCacheLst.isEmpty()){
                system.debug('Enter If 1');
                Set<ID> setIDs = new Set<ID>();
                for(PegaPlansCache__c obj: ppCacheLst){
                    setIDs.add(obj.Product__c);
                }
                system.debug('set Idss '+setIDs);
                mapPlan_Benefit = P2EhUtility.getPlanBenefitIDs(setIDs);
            }
            /****HCL::END****/
            
            system.debug('ppCacheLst'+ppCacheLst );
            for(PegaPlansCache__c ppCache : ppCacheLst){
                String str = '';
                if(qqPlansStrMap.get(ppCache.PlanID__c)!=null){
                    str = qqPlansStrMap.get(ppCache.PlanID__c);
                }
                qqPlansStrMap.put(ppCache.PlanID__c, str + ppCache.PlansJSON__c);
            }
            system.debug('qqPlansStrMap***'+qqPlansStrMap);
            for(String planId : qqPlansStrMap.keyset()){
                System.debug('Plan id**' + planId);
                System.debug (qqPlansStrMap.get(planId) );           
                plansList.add((P2EwPegaService.QQPlans) System.JSON.deserialize(qqPlansStrMap.get(planId), P2EwPegaService.QQPlans.class));
            }
            system.debug('Plan List***'+plansList);
        /*}else{
            plansList = P2EhGlobalUtil.planPPCMap.values();
        }*/
        Integer prdCount = 0;
        
        if(plansList.isEmpty()){
            //throw new
        }else{
            //String RFPCaseId;
            //For IMPL NOTES
            Map<Id,Quote> quoteMap = new Map<Id,Quote>();
            Map<Id, List<P2EwPegaService.QQNotes>> prdSalesNotes = new Map<Id, List<P2EwPegaService.QQNotes>>();
            for(P2EwPegaService.QQPlans qqPlan : plansList){
                if(allPlansUW!=null && qqPlan.PlanID!=null){
                    if(allPlansUW.get(qqPlan.PlanID)!=null && allPlansUW.get(qqPlan.PlanID).UWQuestionnaire__c!=null){
                        String jsons = allPlansUW.get(qqPlan.PlanID).UWQuestionnaire__c.replace('&quot;','"');
                        qqPlan.UWQuestionnaire = (P2EwPegaService.QQUWQuestionnaire) JSON.deserialize(jsons, P2EwPegaService.QQUWQuestionnaire.class);
                    }
                    if(allPlansUW.get(qqPlan.PlanID)!=null && allPlansUW.get(qqPlan.PlanID).Implementation_Notes__c!=null){
                        qqPlan.ImplementationNotes = allPlansUW.get(qqPlan.PlanID).Implementation_Notes__c;
                    }
                    if(allPlansUW.get(qqPlan.PlanID)!=null && allPlansUW.get(qqPlan.PlanID).Benefit_Notes__c!=null){
                        qqPlan.BenefitNotes = allPlansUW.get(qqPlan.PlanID).Benefit_Notes__c;
                    }
                    if(reqName == 'IMPL'){//added by Geetha for PC-15498
                        if(allPlansUW.get(qqPlan.PlanID)!=null && allPlansUW.get(qqPlan.PlanID).GroupPlanName__c!=null){
                            qqPlan.GroupPlanName = allPlansUW.get(qqPlan.PlanID).GroupPlanName__c;
                        }
                        List<P2EwPegaService.QQBenefitPackages> qqBPIds = new List<P2EwPegaService.QQBenefitPackages>();                
                        //for(ProdBenefit__c ProdBenefit: [SELECT ID,Name,Benefit_Package__c,Benefit_Package_ID__c,Product__c FROM ProdBenefit__c WHERE Product__c=:prd.Id]){ Commented by Geetha for PC-15498
                        if(!mapPrdIdPrdBen.isEmpty() && mapPrdIdPrdBen.get(allPlansUW.get(qqPlan.PlanID).Id)!=null && mapPrdIdPrdBen.containsKey(allPlansUW.get(qqPlan.PlanID).Id)){
                            for(ProdBenefit__c ProdBenefit:mapPrdIdPrdBen.get(allPlansUW.get(qqPlan.PlanID).Id)){
                                system.debug('ProdBenefit----- '+ ProdBenefit);
                                qqBPIds.add(new P2EwPegaService.QQBenefitPackages(ProdBenefit.Benefit_Package_ID__c));
                            }
                        }   
                        system.debug('qqBPIds ----- '+ qqBPIds);
                        qqPlan.BenefitPackages = qqBPIds;
                    }//PC-15498 End
                    /****HCL::START Update BenefitPackageID to comma separated values from BenefitPackage Object****/
                    if(mapPlan_Benefit!=null && mapPlan_Benefit.size()>0){
                        qqPlan.BenefitPackageID = mapPlan_Benefit.get(qqPlan.PlanID);
                    }
                    /****HCL::END****/
                }
            }
            
            /****HCL::START Zip Pricing in RFP Request ****/
            System.debug(LoggingLevel.ERROR,'****ZIP PRICING: Req Name: ' + reqName);
            if(reqName != 'IMPL' && pIds!=null && pIds.size()>0){
                List<Product2> prodList = new List<Product2>([Select Id, PlanID__c, Pricing__c, Smile_way__c, DeltaRetainedSavings__c from Product2 where Id IN :pIds]);
                Map<String, Product2> planIdToProd = new Map<String, Product2>();
                for(Product2 prod : prodList){
                    planIdToProd.put(prod.PlanID__c, prod);
                }
                System.debug(LoggingLevel.ERROR, '****ZIP PRICING: prodToPricing: ' + planIdToProd);
                for(P2EwPegaService.QQPlans qqPlan : plansList){
                    System.debug(LoggingLevel.ERROR, '****ZIP PRICING: qqplan.PlanID: ' + qqPlan.PlanID);
                    if(planIdToProd.get(qqPlan.PlanID)!=null){
                        qqPlan.Pricing = planIdToProd.get(qqPlan.PlanID).Pricing__c;
                        qqPlan.DeltaRetainedSavings = planIdToProd.get(qqPlan.PlanID).DeltaRetainedSavings__c!=null?String.valueOf(planIdToProd.get(qqPlan.PlanID).DeltaRetainedSavings__c):'0.0';
                        qqPlan.SmileWay = planIdToProd.get(qqPlan.PlanID).Smile_way__c; //Added for 2-way communication
                    }
                    
                }
            }
            /****HCL::END****/
            
            Set<Id> qIds = new Set<Id>();    
            if(reqName == 'IMPL'){
                set<Id> prodId = new set<Id>();
                for(P2EwPegaService.QQPlans qqPlan : plansList){
                    prodId.add(qqPlan.Product2ID);
                }                
                
                system.debug('++prodId'+prodId);
                List<OpportunityLineItem> oliList = [select id,name,Product2Id,Decision_Status__c,RFP_Case_Id__c from OpportunityLineItem where Opportunity.Id=:opp.Id and (Decision_Status__c='Sold' or (Decision_Status__c='Not - Sold' and Action__c='Discontinue')) and Product2Id IN:prodId];
                List<Implementation_Notes__c> noteInfoList = [select id,createdDate,Implementation_Notes__c,OLI_IDs__c,Parent_Impl_Case_Id__c,Opportunity__c,Title__c from Implementation_Notes__c where Opportunity__c=:opp.Id];//13439
                system.debug('++oliList '+oliList );
                Set<String> RFPId = new Set<String>();
                
                //13439 by geetha on nov11
                List<String> oliIdList = new List<String>();
                List<Implementation_Notes__c> implNotesList = new List<Implementation_Notes__c>();
                //till here for 13439
                
                
                for(OpportunityLineItem oli:oliList){
                     RFPId.add(oli.RFP_Case_Id__c);
                     oliIdList.add(oli.Id);
                }
                
                //13439
                if((!noteInfoList.isEmpty() || noteInfoList.size()>0) && (!oliIdList.isEmpty() || oliIdList.size()>0)){
                    set<id> notIdSet = new set<id>();
                    for(String oliId:oliIdList){                     
                        for(Implementation_Notes__c implNote:noteInfoList){                                    
                            if(implNote.OLI_IDs__c!=null && implNote.OLI_IDs__c.contains(oliId) && !notIdSet.contains(implnote.Id)){
                                notIdSet.add(implnote.Id);  
                                implNotesList.add(implNote);
                            }
                        }
                    }
                }
                if(!implNotesList.isEmpty() || implNotesList.size()>0){
                    List<P2EwPegaService.QQNotes> qqNotes = new List<P2EwPegaService.QQNotes>();
                    for(Implementation_Notes__c implNote:implNotesList){
                        qqNotes.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(implNote.Implementation_Notes__c)), implNote.createdDate));
                    }
                    qqOpportunity.SalesNotesList = qqNotes;
                }
                if(opp.Sales_Notes_for_Implementation__c != Null){
                    qqOpportunity.SalesNotes = EncodingUtil.base64Encode(Blob.valueOf(opp.Sales_Notes_for_Implementation__c));
                }
                //till here for 13439
                
                
                system.debug('++RFPId'+RFPId);
                Map<Id, Quote> quoteList = new Map<Id, Quote>([select id,name,Sales_Notes__c,UW_Notes__c,RFP_Case_Id__c from quote where RFP_Case_Id__c in: RFPId]);
                system.debug('++quoteList '+quoteList.values() );
                qIds = quoteList.keySet();
                for(OpportunityLineItem oli:oliList){
                   for(quote q:quoteList.values() ){
                       if(oli.RFP_Case_Id__c == q.RFP_Case_Id__c ){
                           quoteMap.put(oli.Product2Id,q);
                       }
                   }
                }
                
                List<P2EwPegaService.QQNotes> qqNotes = new List<P2EwPegaService.QQNotes>();
                
                Map<Id, List<P2EwPegaService.QQNotes>> quotSalesNotes = new Map<Id, List<P2EwPegaService.QQNotes>>();
                List<P2EwPegaService.QQNotes> noteLst;
                /*
                for(Note notee : P2EhUserModeUtil.queryNote(quoteMap.values())){
                    if(quotSalesNotes.get(notee.parentId)!=null){
                        noteLst = quotSalesNotes.get(notee.parentId);
                    }else{
                        noteLst = new List<P2EwPegaService.QQNotes>();
                    }
                    noteLst.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(notee.body)), notee.createdDate));
                    quotSalesNotes.put(notee.parentId, noteLst);
                    //qqNotes.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(notee.body))));
                }
                */
                
                /**** Modified for Notes Changes ****/
                for(Implementation_Notes__c notee : P2EhUserModeUtil.queryNote(quoteMap.values())){
                    if(quotSalesNotes.get(notee.Quote__c)!=null){
                        noteLst = quotSalesNotes.get(notee.Quote__c);
                    }else{
                        noteLst = new List<P2EwPegaService.QQNotes>();
                    }
                    noteLst.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(notee.Implementation_Notes__c)), notee.createdDate));
                    quotSalesNotes.put(notee.Quote__c, noteLst);
                }
                /**** Modified for Notes Changes ****/
                for(Id prdId : quoteMap.keyset()){
                    if(prdSalesNotes.get(prdId)==null){
                        prdSalesNotes.put(prdId, quotSalesNotes.get(quoteMap.get(prdId).Id));
                    }
                }
            }
            
            system.debug('++quoteMap'+quoteMap);
            System.debug(LoggingLevel.ERROR, '***QuoteIds: ' + qIds);
            //Add the segments in the request
            /*Set<Id> segmentId = new Set<Id>();
            Map<String,Id> allIds = new Map<String,Id>();
            if(reqName == 'RFP' || reqName=='Renewal'){
                if(cache != NULL && cache.prodSegments != NULL){
                    for(Set<Id> segIds : cache.prodSegments.values()){
                        segmentId.addAll(segIds);
                    }
                }
                
               for(ProdSegment__c prodseg : [select id,Product__c,RateSheet__c,Segmentation__c from ProdSegment__c where Product__c In:cache.prodSegments.KeySet()]){
                   allIds.put(string.valueOf(prodseg.Product__c)+string.valueOf(prodseg.Segmentation__c),prodseg.RateSheet__c);
               }
                                                                       
            }
            Map<Id,Segmentation__c> allSegs;
            if(!segmentId.isEmpty()){
                allSegs = new Map<Id,Segmentation__c>([select id, name, Number_of_Eligible_Employees__c,Number_of_Total_Employees_for_Segments__c,Eligible_Primary_Enrollees__c,Number_of_Total_Employees__c,Number_of_Eligible_Employees_for_Segment__c,Effective_Date__c,End_Date__c,RecordType.Name from segmentation__c where id in: segmentId]);
            }
            //Commenting since segment should not go under plan
                for(P2EwPegaService.QQPlans qqPlan : plansList){
                    if(qqPlan.segments == null){
                        qqPlan.segments = new List<P2EwPegaService.QQSegments>();
                    }
                    if(cache != NULL && cache.prodSegments != NULL){
                        if(cache.prodSegments.get(qqPlan.Product2ID) != null && allSegs != Null){            // Added allSeg != null on 06-09-2016 by Jagan A P
                            for(Id segId : cache.prodSegments.get(qqPlan.Product2ID)){
                                if(allSegs.get(segId) != null){
                                   Segmentation__c seg = allSegs.get(segId);
                                   P2EwPegaService.QQSegments qqSeg = new P2EwPegaService.QQSegments(Integer.valueOf(seg.Number_of_Eligible_Employees__c),seg.name);
                                   qqSeg.SegmentID = seg.Id;
                                   qqSeg.EligibleEmployees=seg.Number_of_Eligible_Employees_for_Segment__c; 
                                   qqSeg.SegmentName= seg.name;
                                   qqSeg.TotalEmployees= seg.Number_of_Total_Employees__c;
                                   qqSeg.EligiblePrimaryEnrollees= seg.Eligible_Primary_Enrollees__c;
                                   qqSeg.TotalEmployeesforsegments= seg.Number_of_Total_Employees_for_Segments__c;
                                   qqSeg.EligiblePrimaryEnrolleesforSegment= seg.Number_of_Eligible_Employees_for_Segment__c; 
                                   qqSeg.SegEffectiveDate = seg.Effective_Date__c;
                                   qqSeg.SegEndDate = seg.End_Date__c; 
                                   qqSeg.Type = seg.RecordType.Name;                            
                                   qqPlan.segments.add(qqSeg);
                               }
                            }
                        }
                    }
                }*/
                if(reqName == 'RFP' || reqName=='Renewal' || reqname=='Change' || reqname=='IMPL'){//Updated by Geetha for PC-13347 on 9/30/16
                Set<Id> ProdId = new Set<Id>();                
                set<id> segmentId = new Set<id>();
                for(P2EwPegaService.QQPlans qqPlan : plansList){
                    ProdId.add(qqplan.Product2ID);
                }
                system.debug('ProdId'+ProdId);
                List<ProdSegment__c> ProdSegList = [select id,Product__c,RateSheet__c,Segmentation__c from ProdSegment__c where Product__c in:ProdId and Segmentation__c!=null and Is_Active__c=true];
                system.debug('ProdSegList'+ProdSegList);
                if(ProdSegList!=null || ProdSegList.size()>0 || !ProdSegList.isEmpty()){         
                    for(ProdSegment__c prodseg: ProdSegList){
                        segmentId.add(prodseg.Segmentation__c);
                        if(prodseg.Product__c!=null){
                            if(mapProdWithSeg.get(prodseg.Product__c)==null){
                                mapProdWithSeg.put(prodseg.Product__c,new Set<id>());
                            }
                            mapProdWithSeg.get(prodseg.Product__c).add(prodseg.Segmentation__c);
                        }                    
                        if(prodseg.RateSheet__c!=null){
                            if(mapRatesheetWithSeg.get(prodseg.RateSheet__c)==null){
                                mapRatesheetWithSeg.put(prodseg.RateSheet__c,new Set<id>());
                            }
                            mapRatesheetWithSeg.get(prodseg.RateSheet__c).add(prodseg.Segmentation__c);
                        }                                                   
                    }
                }
                system.debug('mapProdWithSeg'+mapProdWithSeg);
                system.debug('mapRatesheetWithSeg'+mapRatesheetWithSeg);
                segList = new Map<Id,Segmentation__c>([select id, name, Number_of_Eligible_Employees__c,Number_of_Total_Employees_for_Segments__c,Eligible_Primary_Enrollees__c,Number_of_Total_Employees__c,Number_of_Eligible_Employees_for_Segment__c,Effective_Date__c,End_Date__c,RecordType.Name, MTV_DivisionNumber__c from segmentation__c where id in: segmentId]); 
                system.debug('segList'+segList);
                if(!segList.isEmpty()){                               
                    for(P2EwPegaService.QQPlans qqPlan : plansList){
                        if(qqPlan.segments == null){
                            qqPlan.segments = new List<P2EwPegaService.QQSegments>();
                        }
                        if(!mapProdWithSeg.isEmpty() && mapProdWithSeg.get(qqplan.Product2ID)!=null){
                            for(Id segId: mapProdWithSeg.get(qqplan.Product2ID)){
                               if(segList.get(segId) != null){
                                   Segmentation__c seg = segList.get(segId);                    
                                   P2EwPegaService.QQSegments qqSeg = new P2EwPegaService.QQSegments(Integer.valueOf(seg.Number_of_Eligible_Employees__c),seg.name);
                                   qqSeg.SegmentID = seg.Id;
                                   qqSeg.EligibleEmployees=seg.Number_of_Eligible_Employees_for_Segment__c; 
                                   /****HCL::START Mapped Division Number instead of Segment Name as part of 3.2.1 UAT****/
                                   //qqSeg.SegmentName= seg.name;
                                   qqSeg.SegmentName= seg.MTV_DivisionNumber__c;
                                   /****HCL::END****/
                                   qqSeg.TotalEmployees= seg.Number_of_Total_Employees__c;
                                   qqSeg.EligiblePrimaryEnrollees= seg.Eligible_Primary_Enrollees__c;
                                   qqSeg.TotalEmployeesforsegments= seg.Number_of_Total_Employees_for_Segments__c;
                                   qqSeg.EligiblePrimaryEnrolleesforSegment= seg.Number_of_Eligible_Employees_for_Segment__c; 
                                   qqSeg.SegEffectiveDate = seg.Effective_Date__c;
                                   qqSeg.SegEndDate = seg.End_Date__c; 
                                   qqSeg.Type = seg.RecordType.Name;                            
                                   qqPlan.segments.add(qqSeg);
                               }
                            }
                        }         
                    }
                }else{
                    Set<Id> segmentIds = new Set<Id>();
                    Map<String,Id> allIds = new Map<String,Id>();
                    if(reqName == 'RFP' || reqName=='Renewal'){
                        if(cache != NULL && cache.prodSegments != NULL){
                            for(Set<Id> segIds : cache.prodSegments.values()){
                                segmentIds.addAll(segIds);
                            }
                        }
                        
                       for(ProdSegment__c prodseg : [select id,Product__c,RateSheet__c,Segmentation__c from ProdSegment__c where Product__c In:cache.prodSegments.KeySet()]){
                           allIds.put(string.valueOf(prodseg.Product__c)+string.valueOf(prodseg.Segmentation__c),prodseg.RateSheet__c);
                       }
                                                                               
                    }
                    Map<Id,Segmentation__c> allSegs;
                    if(!segmentIds.isEmpty()){
                        allSegs = new Map<Id,Segmentation__c>([select id, name, Number_of_Eligible_Employees__c,Number_of_Total_Employees_for_Segments__c,Eligible_Primary_Enrollees__c,Number_of_Total_Employees__c,Number_of_Eligible_Employees_for_Segment__c,Effective_Date__c,End_Date__c,RecordType.Name from segmentation__c where id in: segmentIds]);
                    }
                    //Commenting since segment should not go under plan
                    for(P2EwPegaService.QQPlans qqPlan : plansList){
                        if(qqPlan.segments == null){
                            qqPlan.segments = new List<P2EwPegaService.QQSegments>();
                        }
                        if(cache != NULL && cache.prodSegments != NULL){
                            if(cache.prodSegments.get(qqPlan.Product2ID) != null && allSegs != Null){            // Added allSeg != null on 06-09-2016 by Jagan A P
                                for(Id segId : cache.prodSegments.get(qqPlan.Product2ID)){
                                    if(allSegs.get(segId) != null){
                                       Segmentation__c seg = allSegs.get(segId);
                                       P2EwPegaService.QQSegments qqSeg = new P2EwPegaService.QQSegments(Integer.valueOf(seg.Number_of_Eligible_Employees__c),seg.name);
                                       qqSeg.SegmentID = seg.Id;
                                       qqSeg.EligibleEmployees=seg.Number_of_Eligible_Employees_for_Segment__c; 
                                       qqSeg.SegmentName= seg.name;
                                       qqSeg.TotalEmployees= seg.Number_of_Total_Employees__c;
                                       qqSeg.EligiblePrimaryEnrollees= seg.Eligible_Primary_Enrollees__c;
                                       qqSeg.TotalEmployeesforsegments= seg.Number_of_Total_Employees_for_Segments__c;
                                       qqSeg.EligiblePrimaryEnrolleesforSegment= seg.Number_of_Eligible_Employees_for_Segment__c; 
                                       qqSeg.SegEffectiveDate = seg.Effective_Date__c;
                                       qqSeg.SegEndDate = seg.End_Date__c; 
                                       qqSeg.Type = seg.RecordType.Name;                            
                                       qqPlan.segments.add(qqSeg);
                                   }
                                }
                            }
                        }
                    }
                }
            }//End of PC-13347 
            Map<String, List<P2EwPegaService.QQRateSheets>> qqRsMap;
            
            /****HCL::START - Modified to consider only new Rate Sheets for Renewal Implementation****/
            if(reqName != 'IMPL'){
                //qqRsMap = P2EhWizardUtil.frameQQRateSheet(cache.createdQuote.Id, null);
                qqRsMap = P2EhWizardUtil.frameQQRateSheet(cache.createdQuote.Id, null, qIds);
            }else{
                System.debug(LoggingLevel.ERROR, 'JBS****Renewal IMPL Case - framing RateSheet: ' + cache);
                //qqRsMap = P2EhWizardUtil.frameQQRateSheet(null, prodIds);
                qqRsMap = P2EhWizardUtil.frameQQRateSheet(null, prodIds, qIds);
            }
            /****HCL::END****/
            
            system.debug(qqRsMap+'Line 554'+prodIds);
            Decimal totalComm;
            
            Opportunity Renoppt;
            Opportunity prevoppt;            
            opportunity oppt1;
            if(cache!=null){
                oppt1 = [select id,name,Renewal_Opportunity__c,type from opportunity where Id =: cache.selectedopportunity.Id];
                
                if(oppt1.Renewal_Opportunity__c!=null){
                    RenOppt = [select id,name,Old_Opportunity_Name__c from opportunity where Id =: oppt1.Renewal_Opportunity__c]; 
                    prevoppt= [select id,name,closedate from opportunity where Id =: RenOppt.Old_Opportunity_Name__c];
                    
                }
            }
            
            for(P2EwPegaService.QQPlans qqPlan : plansList){
                //Broker Commission Calculation
                totalComm = 0.0;
                if(qqPlan.Broker!=null && !qqPlan.Broker.isEmpty()){                   
                    for(P2EwPegaService.QQBroker brok : qqPlan.Broker){
                        if(brok!=null && brok.Commission!=null && brok.Commission.CurrentCommission!=null){
                            totalComm += brok.Commission.CurrentCommission;
                        }
                    }
                }
                
                if(reqName == 'IMPL' ){
                    if(quoteMap.get(qqPlan.Product2ID) != null){
                        if(quoteMap.get(qqPlan.Product2ID).Sales_Notes__c != null){
                            qqPlan.SalesNotes = EncodingUtil.base64Encode(Blob.valueOf(quoteMap.get(qqPlan.Product2ID).Sales_Notes__c));  
                            qqPlan.SalesNotesList = prdSalesNotes.get(qqPlan.Product2ID);
                        }
                        /*if(quoteMap.get(qqPlan.Product2ID).UW_Notes__c != null){
                            qqPlan.UWNotes = EncodingUtil.base64Encode(Blob.valueOf(quoteMap.get(qqPlan.Product2ID).UW_Notes__c));
                        } *///commented for UWNotes
                        qqPlan.QuoteID = quoteMap.get(qqPlan.Product2ID).id;
                        /****HCL::START - PR-22 - Update PRCaseID to the JSON in implementation phase****/
                        qqPlan.PRCaseID = quoteMap.get(qqPlan.Product2ID).RFP_Case_Id__c;
                        /****HCL::END****/
                    }
                }
                if(reqName.equals('IMPL') || (reqName.equals('Renewal')) || (reqName.equals('Change')) || ((cache.wizardType=='Re-Rate') && (reqName.equals('RFP'))) || ((cache.wizardType=='Re-Rate') && (reqName.equals('Renewal'))) || ((cache.wizardType=='Re-Rate') && (reqName.equals('Change')))){
                    system.debug('qqplan'+qqPlan);
                     /****PC-16885 changes Start****/
                    /*  if(qqPlan.ImplementationNotes != null){
                        qqPlan.ImplementationNotes = EncodingUtil.base64Encode(Blob.valueOf(qqPlan.ImplementationNotes));
                    } */
                     if(allPlansUW.get(qqPlan.PlanID).Implementation_Notes__c != null){
                        qqPlan.ImplementationNotes = EncodingUtil.base64Encode(Blob.valueOf(allPlansUW.get(qqPlan.PlanID).Implementation_Notes__c));
                    }
                     else 
                    {
                         qqPlan.ImplementationNotes = Null;
                    }
                     /****PC-16885 changes End****/
                    
                                                                 
                     if(qqPlan.BenefitNotes != null){
                         qqPlan.BenefitNotes = EncodingUtil.base64Encode(Blob.valueOf(qqPlan.BenefitNotes));
                     }
                       
                  }
                
                if(reqName != 'IMPL'){
                    if(cache.allPlansMap.get(qqPlan.PlanID) != Null){                    
                        qqPlan.Type = cache.allPlansMap.get(qqPlan.PlanID).action;
                        qqPlan.GroupNumber = cache.allPlansMap.get(qqPlan.PlanID).GroupNumber;
                        qqPlan.IsOfferedPlan = cache.allPlansMap.get(qqPlan.PlanID).isOffered;
                        qqPlan.SmileWay = cache.allPlansMap.get(qqPlan.PlanID).isSmileWay; //Added for 2-way communication
                        qqPlan.GroupPlanName = cache.allPlansMap.get(qqPlan.PlanID).GroupPlanName;//Geetha PC-15498
                        List<P2EwPegaService.QQBenefitPackages> qqBPIds = new List<P2EwPegaService.QQBenefitPackages>();
                        if(cache.allPlansMap.get(qqPlan.PlanID).BenefitPackages!=null){                        
                            for(String ProdBenefitId:cache.allPlansMap.get(qqPlan.PlanID).BenefitPackages){
                                qqBPIds.add(new P2EwPegaService.QQBenefitPackages(ProdBenefitId));
                            }                            
                        }
                        qqPlan.BenefitPackages = qqBPIds;//Geetha code End for PC-15498
                        //qqPlan.IsCurrentPlan = cache.allPlansMap.get(qqPlan.PlanID).isCurrentPlan;
                        qqPlan.OriginalPlan = cache.allPlansMap.get(qqPlan.PlanID).isOldPlan;
                        //if(cache.wizardType=='Re-Rate')for normal RFP request, OSRPlanId will be sent as null and for other requests OSRPlanId will be populated with the values received from SF001 request.
                            qqPlan.OSRPlanID = cache.allPlansMap.get(qqPlan.PlanID).OsrPlanId;
                            //qqPlan.OSRPlan = cache.allPlansMap.get(qqPlan.PlanID).isOSRPlan;//13674
                            qqPlan.OSRPlanSFDC = cache.allPlansMap.get(qqPlan.PlanID).isOSRPlan; //PC-15155
                            //qqplan.HasClaimsExperience = cache.allPlansMap.get(qqPlan.PlanID).isClaimsExperience;//added by geetha for JIRA 5511
                            //qqPlan.effectivedate = dateToStr(cache.allPlansMap.get(qqPlan.PlanID).effectivedate); 
                            if((cache.allPlansMap.get(qqPlan.PlanID).effectiveDate == null || cache.allPlansMap.get(qqPlan.PlanID).action == 'Existing' || cache.allPlansMap.get(qqPlan.PlanID).action == 'Discontinue' || cache.allPlansMap.get(qqPlan.PlanID).action == 'Delete') && oppt1.type != 'Change'){
                                system.debug('inside if 1');
                                qqplan.effectivedate = dateToStr(cache.selectedOpportunity.closedate);               
                            }
                            else if((cache.allPlansMap.get(qqPlan.PlanID).effectiveDate == null || cache.allPlansMap.get(qqPlan.PlanID).action == 'Existing' || cache.allPlansMap.get(qqPlan.PlanID).action == 'Discontinue' || cache.allPlansMap.get(qqPlan.PlanID).action == 'Delete') && oppt1.type == 'Change')
                            {
                                system.debug('inside if 2');                                        
                                qqplan.effectivedate = dateToStr(prevoppt.closedate);                                               
                            }
                            else if(cache.allPlansMap.get(qqPlan.PlanID).effectiveDate != null){
                                qqplan.effectivedate =  dateToStr(cache.allPlansMap.get(qqPlan.PlanID).effectivedate); 
                            }
                        
                        //Done as per CR - PC-9402 - Hitendar
                        if(qqPlan.Type != 'New' && qqPlan.OONReimbursement == 'Others'){
                            qqPlan.NPAlwSchedule = '';
                        }
                    }
                }else{
                    if(mapProdOLI.get(qqPlan.Product2Id).Action__c != Null){
                        qqPlan.Type = mapProdOLI.get(qqPlan.Product2Id).Action__c;
                    }
                    if(mapProdOLI.get(qqPlan.Product2Id).IsRateUpdated__c != Null){
                        qqPlan.RateUpdated = mapProdOLI.get(qqPlan.Product2Id).IsRateUpdated__c;
                    }
                    if(mapProdOLI.get(qqPlan.Product2Id).Effective_Date__c != Null){
                        qqPlan.effectivedate = dateToStr(mapProdOLI.get(qqPlan.Product2Id).Effective_Date__c);
                    }
                    qqPlan.GroupNumber = mapProdOLI.get(qqPlan.Product2Id).Group_Number__c;
                    //RFPCaseId = mapProdOLI.get(qqPlan.Product2Id).RFP_Case_Id__c;//RfpCaseId__c;
                    if(mapProdOLI.get(qqPlan.Product2Id).Decision_Status__c != 'Sold'){
                        qqPlan.Discontinued = true;
                    }
                    //Done as per CR - PC-9402 - Hitendar
                    if(qqPlan.Type != 'New' && qqPlan.OONReimbursement == 'Others'){
                        qqPlan.NPAlwSchedule = '';
                    }
                }
                
                if(qqPlan.Type == 'Existing' || qqPlan.Type == 'Delete' || qqPlan.Type == 'Discontinue'){
                    qqPlan.IsCurrentPlan = True;
                }
                if(qqPlan.Type ==  'New' || qqPlan.Type == 'Update'){
                    qqPlan.IsCurrentPlan = false;
                }
                
                if(cache != NULL){
                    if(cache.allPlansMap.get(qqPlan.PlanID) != NULL){
                        if(cache.allPlansMap.get(qqPlan.PlanID).isCurrentPlan != NULL){
                            if(cache.allPlansMap.get(qqplan.PlanID).isCurrentPlan){
                                qqPlan.IsCurrentPlan = True;
                            }                
                        }    
                    }
                }
                qqPlan.ContractStartDate = dateToStr(opp.Contract_Start_Date__c);
                
                if(qqPlan.ProductName =='DHMO'){
                    qqPlan.CurrentPrimaryEnrolee = Integer.valueOf(opp.DHMO_Number_of_Current_Primary_Enrollees__c);
                }
                else{
                    qqPlan.CurrentPrimaryEnrolee = Integer.valueOf(opp.FFS_Number_of_Current_Primary_Enrollees__c);
                }
                //Effective date for existing plan should have the effective date of opportunity
                
                    //Integer dim = Date.daysInMonth(opp.CloseDate.year(),opp.CloseDate.month());
                    //qqPlan.EffectiveDate = P2EhWizardUtil.dateToStr(opp.CloseDate.toStartOfMonth().addDays(dim));
                    //qqPlan.EffectiveDate = P2EhWizardUtil.dateToStr(opp.CloseDate);
                  /*if(cache!= Null){
                      if((qqPlan.Type == 'Existing' || qqPlan.Type == 'Delete' || qqPlan.Type == 'Discontinue')&&){  
                    
                        Date renewalEffectiveDate = cache.selectedOpportunity.closedate;
                        qqPlan.EffectiveDate = dateToStr(renewalEffectiveDate);
                      }
                   
                      else{
                        Date renewalEffectiveDate = cache.allPlansMap.get(qqPlan.PlanID).effectivedate;
                        qqPlan.EffectiveDate = dateToStr(renewalEffectiveDate);
                      }
                  }*/
                if(!((reqName.equals('Quick_Quote') || reqName.equals('EligibilityQQ')) && 
                            (qqPlan.ProductName.equals('DHMO') || (qqPlan.TOA && qqPlan.TOAType == 'Full Schedule')))){
                    prdCount++;
                    system.debug(qqPlan.RateSheets+'line 637');
                    List<P2EwPegaService.QQRateSheets> qqRateSheetList = new List<P2EwPegaService.QQRateSheets>();
                    if(qqRsMap !=null && qqRsMap.containsKey(qqPlan.PlanID)) {
                        qqRateSheetList = qqRsMap.get(qqPlan.PlanID);
                    }// qqPlan.RateSheets; // Place to Change
                    List<P2EwPegaService.QQRateSheets> newQQRateSheetList = new List<P2EwPegaService.QQRateSheets>();
                    P2EwPegaService.QQRateSheets qqRateSheetReq;
                    P2EwPegaService.QQRateSheets qqRateSheetRes;
                    List<P2EwPegaService.QQRateSheets> activeRS= new List<P2EwPegaService.QQRateSheets>();
                    List<P2EwPegaService.QQRateSheets> newRS = new List<P2EwPegaService.QQRateSheets>();
                    
                    Boolean isNew = false;
                    
                    for(P2EwPegaService.QQRateSheets rs : qqRateSheetList){
                            
                         //if(qqPlan.Type == 'New' || qqPlan.Type == 'Update'){
                            //Added the condition for not released plans also
                         //   if(reqName != 'IMPL'){ // && (!cache.allPlansMap.get(qqPlan.PlanID).isOldPlan || !cache.allPlansMap.get(qqPlan.PlanID).RFPRateGenerated)){
                         //System.debug('test_qqPlan.PlanID:' +qqPlan.PlanID);
                         //System.debug('test_cache_plansMap:' +cache.allPlansMap.get(qqPlan.PlanID));
                         if(reqName != 'IMPL' ){
                           //if(reqName != 'IMPL' && !cache.allPlansMap.get(qqPlan.PlanID).isOldPlan && !cache.allPlansMap.get(qqPlan.PlanID).RFPRateGenerated){
                                /*if((rs.Type == 'New' && qqRateSheetList.size() == 1) 
                                        || (rs.Type == 'Activate' && qqRateSheetList.size() >= 1)){*/
                                if((rs.Type == 'New' && qqRateSheetList.size() == 1) 
                                        || (rs.Type == 'Activate' && qqRateSheetList.size() >= 1 && rs.RequestQuote!=null && rs.RequestQuote.contains(cache.createdQuote.Id))
                                         ||(rs.Type == 'Activate' && qqRateSheetList.size() >= 1 && rs.ResponseQuote!=null && rs.ResponseQuote.contains(cache.createdQuote.Id) && rs.RequestQuote == Null) ){
                                    isNew = true;
                                    
                                    List<P2EwPegaService.QQAdminRates> newAdminRates = new List<P2EwPegaService.QQAdminRates>();
                                    Map<String, P2EwPegaService.QQAdminRates> adminRateMap = new Map<String, P2EwPegaService.QQAdminRates>();
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                        adminRateMap.put(aRa.AdminAnalysis, aRa);
                                    }
                                    system.debug('adminRateMap :::' + adminRateMap);
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                        system.debug('aRa.AdminAnalysis ::' + aRa.AdminAnalysis);
                                        if(aRa.AdminAnalysis == 'Proposed-Net'){
                                            adminRateMap.remove(aRa.AdminAnalysis);
                                        }
                                        if(opp.Type == 'New' && (aRa.AdminAnalysis == 'Current Admin' 
                                            || aRa.AdminAnalysis == 'Net Renewal Fee' 
                                            || aRa.AdminAnalysis == 'Net Current Fee'
                                            || aRa.AdminAnalysis == 'Net Renewal Justification'
                                            || aRa.AdminAnalysis == 'Net Justified Fee')){
                                            adminRateMap.remove(aRa.AdminAnalysis);
                                        }
                                        if(opp.Type != 'New' && (aRa.AdminAnalysis == 'Net Renewal Fee' 
                                            || aRa.AdminAnalysis == 'Renewal Fee' 
                                            || aRa.AdminAnalysis == 'Net Current Fee')){
                                            adminRateMap.remove(aRa.AdminAnalysis);
                                        }
                                    }
                                    P2EwPegaService.QQAdminRates adminCommRates = adminRateMap.get('Commission');
                                    system.debug('****'+adminCommRates);
                                    system.debug('adminRateMap :::' + adminRateMap);
                                    //Re-rate and negotation added for commision calculation
                                    for(P2EwPegaService.QQAdminRates aRa : adminRateMap.values()){
                                        if(aRa.AdminAnalysis == 'Current Fee'){
                                            aRa.AdminAnalysis = 'Net Current Fee';
                                            if(aRa.PercentofClaims!=null && adminCommRates.PercentofClaims!=null  && (cache.wizardType!='Re-Rate' && cache.wizardType!='Negotiation')){
                                                aRa.PercentofClaims -= adminCommRates.PercentofClaims;
                                            }
                                            if(aRa.PercentofClaims!=null && totalComm!=null && adminCommRates.PercentofClaims==null  && (cache.wizardType!='Re-Rate' && cache.wizardType!='Negotiation')){
                                                aRa.PercentofClaims -= totalComm;
                                                
                                            }
                                            if(aRa.PEPMRate!=null && adminCommRates.PEPMRate!=null  && (cache.wizardType!='Re-Rate' && cache.wizardType!='Negotiation')){
                                                aRa.PEPMRate -= adminCommRates.PEPMRate;
                                            }
                                            if(aRa.PEPMRate!=null && totalComm!=null && adminCommRates.PEPMRate==null  && (cache.wizardType!='Re-Rate' && cache.wizardType!='Negotiation')){
                                                aRa.PEPMRate -= totalComm;
                                            }
                                        }
                                        if(aRa.AdminAnalysis == 'Renewal Fee'){
                                            aRa.AdminAnalysis = 'Net Renewal Fee';
                                        }
                                        if(aRa.AdminAnalysis == 'Proposed-Net'){
                                            aRa.AdminAnalysis = 'Proposed';
                                        }
                                        if(aRa.AdminAnalysis == 'Proposed'|| aRa.AdminAnalysis == 'Total Proposed' || aRa.AdminAnalysis == 'Proposed-Net' || aRa.AdminAnalysis == 'Proposed Admin'){
                                             aRa.PercentofClaims = null;
                                             aRa.PEPMRate = null;
                                        }
                                        newAdminRates.add(aRa);
                                    }
                                    if((qqPlan.Type == 'Existing' || qqPlan.Type == 'Discontinue') 
                                        || ((qqPlan.Type == 'New' || qqPlan.Type == 'Update') && opp.Type != 'New')){
                                        if(cache.wizardType!='Re-Rate' && opp.type=='Renewal'){
                                            rs.EndDate = null;
                                        }
                                        /*if((qqPlan.ContractType == 'ASC with Stop Loss' || qqPlan.ContractType == 'ASC (Self funded)')){
                                            if(adminRateMap.get('Net Renewal Justification')==null){
                                                P2EwPegaService.QQAdminRates aRa1 = new P2EwPegaService.QQAdminRates();
                                                aRa1.AdminAnalysis = 'Net Renewal Justification';
                                                newAdminRates.add(aRa1);
                                            }
                                            if(adminRateMap.get('Net Justified Fee')==null){
                                                P2EwPegaService.QQAdminRates aRa2 = new P2EwPegaService.QQAdminRates();
                                                aRa2.AdminAnalysis = 'Net Justified Fee';
                                                newAdminRates.add(aRa2);
                                            }
                                        }*/
                                            /*else{
                                            if(adminRateMap.get('Current Admin')==null){
                                                P2EwPegaService.QQAdminRates aRa3 = new P2EwPegaService.QQAdminRates();
                                                aRa3.AdminAnalysis = 'Current Admin';
                                                newAdminRates.add(aRa3);
                                            }
                                        }*///Else part commented for UW Opt
                                    }
                                    rs.AdminRates = newAdminRates;
                                    
                                    if((qqPlan.Type == 'Existing' || qqPlan.Type == 'Discontinue')){
                                        if(rs.OriginalRates!=null && rs.OriginalRates.size()>0){
                                            for(P2EwPegaService.QQOriginalRates oRa : rs.OriginalRates){
                                                if(qqPlan.ContractType == 'Retention (Participating)' 
                                                    || qqPlan.ContractType =='Guaranteed Administration (Participating)'){
                                                    //CurrentBilledRate
                                                    if(oRa.ProposedRate != null && oRa.ProposedBilledRate == null){
                                                        oRa.CurrentBilledRate = oRa.ProposedRate;
                                                        oRa.CurrentRate = oRa.ProposedRate;
                                                    }
                                                    if(oRa.ProposedBilledRate != null){ //oRa.ProposedRate == null && 
                                                        oRa.CurrentBilledRate = oRa.ProposedBilledRate;
                                                        oRa.CurrentRate = oRa.ProposedBilledRate;
                                                        oRa.ProposedBilledRate = null;
                                                    }
                                                    //CurrentSubsidyRate
                                                    if(oRa.ProposedSubsidyRate!=null){
                                                        oRa.CurrentSubsidyRate = oRa.ProposedSubsidyRate;
                                                        oRa.ProposedSubsidyRate = null;
                                                    }
                                                    if(oRa.CurrentSubsidyRate == null){
                                                        oRa.CurrentSubsidyRate = 0;
                                                    }
                                                    //CurrentTotalRate
                                                    if(oRa.ProposedTotalRates != null){
                                                        oRa.CurrentTotalRate = oRa.ProposedTotalRates;
                                                        oRa.ProposedTotalRates = null;
                                                    }
                                                    if(oRa.CurrentBilledRate!=null && oRa.CurrentRate!=null 
                                                        && oRa.CurrentTotalRate==null && oRa.CurrentBilledRate == oRa.CurrentRate){ // && oRa.CurrentSubsidyRate!=null                                                      
                                                        oRa.CurrentTotalRate = oRa.CurrentBilledRate + oRa.CurrentSubsidyRate;
                                                    }
                                                    /*else
                                                    if(oRa.CurrentBilledRate!=null && oRa.CurrentTotalRate==null){ // && oRa.CurrentSubsidyRate!=null                                                      
                                                        oRa.CurrentTotalRate = oRa.CurrentBilledRate + oRa.CurrentSubsidyRate;
                                                        oRa.CurrentRate = oRa.CurrentBilledRate;
                                                    }
                                                    */
                                                    /*
                                                    if(oRa.CurrentTotalRate == NULL && cache.wizardType == 'Re-Rate'){
                                                        oRa.CurrentTotalRate = oRa.CurrentBilledRate + oRa.CurrentSubsidyRate;
                                                    }
                                                    */
                                                    oRa.ProposedRate = null;
                                                    oRa.RequiredRate = null;
                                                    oRa.RenewalRate = null;
                                                }else if(qqPlan.ContractType == 'Non-Retention (Non-Participating)'){
                                                    oRa.CurrentRate = oRa.ProposedRate;
                                                    oRa.ProposedRate = null;
                                                    oRa.RequiredRate = null;
                                                    oRa.RenewalRate = null;
                                                }else if(qqPlan.ContractType == 'ASC with Stop Loss' && oRa.ProposedMaxLiabilityRate != null){
                                                    oRa.CurrMaxLiabilityRate = oRa.ProposedMaxLiabilityRate;
                                                    oRa.CurrentRate = oRa.ProposedMaxLiabilityRate;
                                                    oRa.ProposedMaxLiabilityRate= null; 
                                                    oRa.RequiredRate = null;
                                                    oRa.RenewalRate = null;
                                                }
                                                /*
                                                else if(qqPlan.ContractType == 'ASC with Stop Loss' && oRa.ProposedRate != null){
                                                    oRa.CurrMaxLiabilityRate = oRa.ProposedRate;
                                                    oRa.ProposedRate = null; 
                                                    oRa.RequiredRate = null;
                                                    oRa.RenewalRate = null;
                                                }
                                                */
                                            }
                                        }
                                        //Added for New Json Structure
                                        if(qqPlan.ContractType == 'ASC with Stop Loss' 
                                           || qqPlan.ContractType =='ASC (Self funded)') {
                                               if(rs.ASCFeeBreakdown!=null && rs.ASCFeeBreakdown.size()>0) {
                                                   for(P2EwPegaService.ASCFeeBreakdown AscFee : rs.ASCFeeBreakdown) {
                                                       if(AscFee.ProposedASCFee != null) {                                                           
                                                            AscFee.CurrentASCFee = AscFee.ProposedASCFee;
                                                            AscFee.ComponentBasis = AscFee.ProposedComponentBasis;
                                                            AscFee.ProposedASCFee = null;
                                                            AscFee.ProposedComponentBasis = null;
                                                            AscFee.RenewalASCFee = null;
                                                            AscFee.RenewalComponentBasis = null;
                                                       }

                                                   }
                                               }   
                                           }
                                    }
                                    if((qqPlan.Type == 'New' || qqPlan.Type == 'Update')){
                                        if(rs.OriginalRates!=null && rs.OriginalRates.size()>0){
                                            for(P2EwPegaService.QQOriginalRates oRa : rs.OriginalRates){
                                                if(qqPlan.ContractType == 'Retention (Participating)' 
                                                    || qqPlan.ContractType =='Guaranteed Administration (Participating)'){
                                                    if(oRa.CurrentBilledRate!=null && oRa.CurrentSubsidyRate!=null){
                                                        oRa.CurrentRate = oRa.CurrentBilledRate;
                                                        oRa.CurrentTotalRate = oRa.CurrentBilledRate + oRa.CurrentSubsidyRate;
                                                    }
                                                }else if(qqPlan.ContractType == 'Non-Retention (Non-Participating)'){
                                                    //oRa.CurrentRate
                                                }else if(qqPlan.ContractType == 'ASC with Stop Loss' && oRa.CurrMaxLiabilityRate!=null){
                                                    oRa.CurrentRate = oRa.CurrMaxLiabilityRate;
                                                }
                                            }
                                        }
                                    }
                                    newQQRateSheetList.add(rs);
                                }
                            }
                            //else{
                            //if(reqName == 'IMPL'){
                            Id qId;
                            if(reqName == 'IMPL'){
                                qId = mapRFPQId.get(mapProdOLI.get(qqPlan.Product2Id).RFP_Case_Id__c);
                            //else{
                            //    qId = cache.createdQuote.Id;
                            //}
                            //Added by parthi by 04-01-2016
                                /***** Change By HCL MM *****/
                                    system.debug('M#M :: rs ' +rs + ' qID + ' + qID);
                                    if(qID==null && Test.isRunningTest())
                                        continue;
                                /***** Change By HCL MM *****/
                                if(rs.Type == 'Activate' && ((rs.ResponseQuote!=null && rs.ResponseQuote.contains(qId)) || (rs.RequestQuote!=null && rs.RequestQuote.contains(qId)))){
                                    List<P2EwPegaService.QQAdminRates> newAdminRates = new List<P2EwPegaService.QQAdminRates>();
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                        if(aRa.AdminAnalysis != 'Current Admin' 
                                            && aRa.AdminAnalysis != 'Renewal Fee' 
                                            && aRa.AdminAnalysis != 'Current Fee'
                                            && aRa.AdminAnalysis != 'Proposed-Net'){
                                            newAdminRates.add(aRa);
                                        }
                                    }
                                    rs.AdminRates = newAdminRates;
                                    newQQRateSheetList.add(rs);
                                } //Added by parthi by 04-01-2016                       
                            }
                        //}
                        
                        /*
                        if((qqPlan.Type == 'Existing' || qqPlan.Type == 'Discontinue')){
                            if(reqName != 'IMPL'){
                                if(rs.Type == 'Activate'){
                                    Decimal proposedPclimRT;
                                    Decimal proposedPEPMrt;
                                    Boolean isClaims = false;
                                    Boolean isPEPM = false;
                                    for(P2EwPegaService.QQOriginalRates oRa : rs.OriginalRates){
                                        if(qqPlan.ContractType == 'Retention (Participating)' || qqPlan.ContractType =='Guaranteed Administration (Participating)'){
                                            if(oRa.ProposedRate != null && oRa.ProposedTotalRates == null){
                                              oRa.CurrentBilledRate = oRa.ProposedRate;
                                            }
                                            if(oRa.CurrentSubsidyRate == null){
                                                oRa.CurrentSubsidyRate = 0;
                                            }                                           
                                            oRa.ProposedRate = null;
                                            oRa.RenewalRate = null;
                                        }else if(qqPlan.ContractType == 'Non-Retention (Non-Participating)'){
                                            oRa.CurrentRate = oRa.ProposedRate;
                                            oRa.ProposedRate = null;
                                            oRa.RenewalRate = null;
                                        }else if(qqPlan.ContractType == 'ASC with Stop Loss'){
                                            oRa.CurrMaxLiabilityRate = oRa.ProposedRate;
                                            oRa.ProposedRate = null; 
                                            oRa.RenewalRate = null;
                                        }
                                    }
                                    List<P2EwPegaService.QQAdminRates> arList = new List<P2EwPegaService.QQAdminRates>();
                                    P2EwPegaService.QQAdminRates proposedRate;
                                    P2EwPegaService.QQAdminRates proposedAdminRate;
                                    P2EwPegaService.QQAdminRates CurrentfeeAdminRate;
                                    P2EwPegaService.QQAdminRates RenewalfeeAdminRate;
                                    P2EwPegaService.QQAdminRates CommissionAdminRate;
                                    Boolean currentAdminExists = false;
                                    Integer index = 0;
                                    Integer indexToBeRemoved;
                                    // commision
                                    Integer IntegerToRemoveCurandRen;
                                    Integer IndexCurRen = 0;
                                    
                                    //Added by Parthi, checking whether Net Justified Fee and Net Renewal Justification
                                    //are already present in the list
                                    Boolean isNJF = false;
                                    Boolean isNRJ = false;                                    
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                        if(aRa.AdminAnalysis == 'Net Justified Fee'){
                                            isNJF = true;    
                                        }else if(aRa.AdminAnalysis == 'Net Renewal Justification'){
                                            isNRJ = true;
                                        }
                                    }
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                      system.debug('$$$$123'+aRa.AdminAnalysis);
                                        if(aRa.AdminAnalysis == 'Proposed'){ 
                                            proposedRate = new P2EwPegaService.QQAdminRates();
                                            proposedRate.PercentofClaims =  aRa.PercentofClaims;
                                            proposedRate.PEPMRate =   aRa.PEPMRate; 
                                        }
                                        else if(aRa.AdminAnalysis == 'Proposed Admin'){ 
                                            proposedAdminRate = new P2EwPegaService.QQAdminRates();
                                            proposedAdminRate.PercentofClaims =  aRa.PercentofClaims;
                                            proposedAdminRate.PEPMRate =   aRa.PEPMRate; 
                                        }
                                        //commission
                                        else if(aRa.AdminAnalysis == 'Current Fee'){ 
                                            CurrentfeeAdminRate = new P2EwPegaService.QQAdminRates();
                                            CurrentfeeAdminRate.PercentofClaims =  aRa.PercentofClaims;
                                            CurrentfeeAdminRate.PEPMRate =   aRa.PEPMRate; 
                                        }
                                        else if(aRa.AdminAnalysis == 'Renewal Fee'){ 
                                            RenewalfeeAdminRate= new P2EwPegaService.QQAdminRates();
                                            RenewalfeeAdminRate.PercentofClaims =  aRa.PercentofClaims;
                                            RenewalfeeAdminRate.PEPMRate =   aRa.PEPMRate; 
                                        } 
                                        else if(aRa.AdminAnalysis == 'Commission'){ 
                                            CommissionAdminRate= new P2EwPegaService.QQAdminRates();
                                            CommissionAdminRate.PercentofClaims =  aRa.PercentofClaims;
                                            CommissionAdminRate.PEPMRate =   aRa.PEPMRate; 
                                        } 
                                        else if(aRa.AdminAnalysis == 'Current Admin'){
                                            currentAdminExists = true;
                                        }
                                        else if(aRa.AdminAnalysis == 'Net Renewal Fee'){
                                            indexToBeRemoved = index;
                                        }
                                        index ++;
                                    }
                                    //Remove the 'Net Renewal Fee' from the list
                                   if(indexToBeRemoved != Null){
                                      rs.AdminRates.remove(indexToBeRemoved);
                                    }
                                    
                                    /**********************************
                                    Current admin should be created only for Retention (Participating),
                                    Guaranteed Administration (Participating),Non-Retention (Non-Participating)
                                    Adding below if condition for the same
                                    **********************************
                                    if(qqPlan.ContractType == 'Retention (Participating)' || qqPlan.ContractType =='Guaranteed Administration (Participating)' 
                                        || qqPlan.ContractType == 'Non-Retention (Non-Participating)'){
                                        if(!currentAdminExists){
                                            P2EwPegaService.QQAdminRates newAR = new P2EwPegaService.QQAdminRates();  
                                            newAR.AdminAnalysis = 'Current Admin';
                                            if(proposedAdminRate!= Null){
                                                newAR.PercentofClaims = proposedAdminRate.PercentofClaims;
                                                newAR.PEPMRate = proposedAdminRate.PEPMRate;    
                                            }
                                            arList.add(newAR);  
                                        }
                                    }
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                        if(qqPlan.ContractType == 'Retention (Participating)' || qqPlan.ContractType =='Guaranteed Administration (Participating)' || qqPlan.ContractType == 'Non-Retention (Non-Participating)'){
                                          //removed currentAdminExists from the  condition
                                            if(aRa.AdminAnalysis == 'Current Admin' &&  proposedAdminRate!= null){
                                                      aRa.PercentofClaims = proposedAdminRate.PercentofClaims;
                                                      aRa.PEPMRate = proposedAdminRate.PEPMRate;
                                            }
                                        }else if(qqPlan.ContractType == 'ASC with Stop Loss' || qqPlan.ContractType == 'ASC (Self funded)'){
                                            //Commission
                                           if(aRa.AdminAnalysis == 'Net Renewal Fee' && RenewalfeeAdminRate != null){
                                              aRa.PercentofClaims = RenewalfeeAdminRate.PercentofClaims;
                                                aRa.PEPMRate = RenewalfeeAdminRate .PEPMRate;
                                            }else if(aRa.AdminAnalysis == 'Net Current Fee' && proposedRate != null &&  cache.wizardType != 'Re-Rate'){
                                                if(!isNJF){
                                                    P2EwPegaService.QQAdminRates newARJF = new P2EwPegaService.QQAdminRates();
                                                    newARJF.AdminAnalysis = 'Net Justified Fee';  
                                                    arList.add(newARJF);                                                      
                                                }
                                                if(!isNRJ){
                                                    P2EwPegaService.QQAdminRates newARJ = new P2EwPegaService.QQAdminRates();     
                                                    newARJ.AdminAnalysis = 'Net Renewal Justification';
                                                    arList.add(newARJ);
                                                }
                                                aRa.PercentofClaims = (proposedRate.PercentofClaims - CommissionAdminRate.PercentofClaims);
                                                aRa.PEPMRate = (proposedRate.PEPMRate - CommissionAdminRate.PercentofClaims);
                                            }
                                        }
                                        //Commssion
                                      if(aRa.AdminAnalysis == 'Current Fee' || aRa.AdminAnalysis == 'Renewal Fee'){
                                            IntegerToRemoveCurandRen = IndexCurRen;
                                        }
                                      IndexCurRen++;
                                    }
                                    for(P2EwPegaService.QQAdminRates aRa : rs.AdminRates){
                                      if(aRa.AdminAnalysis == 'Proposed Admin' || aRa.AdminAnalysis == 'Proposed'){
                                          aRa.PercentofClaims = Null;
                                            aRa.PEPMRate = Null;
                                        }
                                    }
                                    if(IntegerToRemoveCurandRen != Null){
                                      rs.AdminRates.remove(IntegerToRemoveCurandRen);
                                        rs.AdminRates.addAll(arList);
                                      newQQRateSheetList.add(rs);
                                  }
                              }
                              if(reqName == 'IMPL'){
                                  if(rs.Type == 'Activate'){
                                      newQQRateSheetList.add(rs);
                                  }
                              }
                          }
                        }
                        */
                    }
                       
                   //Segment under ratesheet
                   system.debug('Line 1011' + newQQRateSheetList);
                    /*for(P2EwPegaService.QQRateSheets rs : newQQRateSheetList){
                        if(rs.Segments == null){
                            rs.Segments = new List<P2EwPegaService.QQSegments>();
                        }
                        if(cache != NULL && cache.prodSegments != NULL && allSegs!=null){ //&& (allIds!=null && !isNew)
                            if(cache.prodSegments.get(qqPlan.Product2ID) != null){
                                for(Id segId : cache.prodSegments.get(qqPlan.Product2ID)){
                                    if(isNew || (rs.RateSheetId == allIds.get(String.valueOf(qqPlan.Product2ID)+String.valueOf(segId)) && !isNew)){
                                        if(allSegs.get(segId) != null){
                                           Segmentation__c seg = allSegs.get(segId);
                                           P2EwPegaService.QQSegments qqSeg = new P2EwPegaService.QQSegments(Integer.valueOf(seg.Number_of_Eligible_Employees__c),seg.name);
                                           qqSeg.SegmentID = seg.Id;
                                           qqSeg.EligibleEmployees=seg.Number_of_Eligible_Employees_for_Segment__c; 
                                           qqSeg.SegmentName= seg.name;
                                           qqSeg.TotalEmployees= seg.Number_of_Total_Employees__c;
                                           qqSeg.EligiblePrimaryEnrollees= seg.Eligible_Primary_Enrollees__c;
                                           qqSeg.TotalEmployeesforsegments= seg.Number_of_Total_Employees_for_Segments__c;
                                           qqSeg.EligiblePrimaryEnrolleesforSegment= seg.Number_of_Eligible_Employees_for_Segment__c; 
                                           qqSeg.SegEffectiveDate = seg.Effective_Date__c;
                                           qqSeg.SegEndDate = seg.End_Date__c; 
                                           qqSeg.Type = seg.RecordType.Name;                           
                                           rs.segments.add(qqSeg);
                                       }
                                   }
                                }
                            }
                        }
                    }*/
                    if(reqName == 'RFP' || reqName=='Renewal' || reqname=='Change' || reqname=='IMPL'){
                        if(!segList.isEmpty()){                  
                            for(P2EwPegaService.QQRateSheets rs : newQQRateSheetList){ //Updated by Geetha for PC-13347 on 9/30/16                   
                                if(rs.Segments == null){
                                    rs.Segments = new List<P2EwPegaService.QQSegments>();                
                                }        
                                if(mapRatesheetWithSeg.get(rs.RateSheetId)!=null){
                                    for(Id segId: mapRatesheetWithSeg.get(rs.RateSheetId)){
                                       if(segList.get(segId) != null){
                                           Segmentation__c seg = segList.get(segId);                    
                                           P2EwPegaService.QQSegments qqSeg = new P2EwPegaService.QQSegments(Integer.valueOf(seg.Number_of_Eligible_Employees__c),seg.name);
                                           qqSeg.SegmentID = seg.Id;
                                           qqSeg.EligibleEmployees=seg.Number_of_Eligible_Employees_for_Segment__c; 
                                           /****HCL::START Assign Division Number instead of Segment Name****/
                                           //qqSeg.SegmentName= seg.name;
                                           qqSeg.SegmentName = seg.MTV_DivisionNumber__c;
                                           /****HCL::END****/
                                           qqSeg.TotalEmployees= seg.Number_of_Total_Employees__c;
                                           qqSeg.EligiblePrimaryEnrollees= seg.Eligible_Primary_Enrollees__c;
                                           qqSeg.TotalEmployeesforsegments= seg.Number_of_Total_Employees_for_Segments__c;
                                           qqSeg.EligiblePrimaryEnrolleesforSegment= seg.Number_of_Eligible_Employees_for_Segment__c; 
                                           qqSeg.SegEffectiveDate = seg.Effective_Date__c;
                                           qqSeg.SegEndDate = seg.End_Date__c; 
                                           qqSeg.Type = seg.RecordType.Name;                            
                                           rs.segments.add(qqSeg);
                                       }
                                    }                    
                                }                    
                            }
                       }
                    }//End of PC-13347 
                    qqPlan.RateSheets = newQQRateSheetList;
                    
                    Boolean isBenefitChange = false;
                    //qqPlan.Type = cache.allPlansMap.get(qqPlan.PlanID).action;
                    //qqPlan.GroupNumber = cache.allPlansMap.get(qqPlan.PlanID).GroupNumber;
                    if(reqName.equals('Renewal') || reqName.equals('Change') || reqName.equals('IMPL')){
                        //qqPlan.GroupNumber = cache.allPlansMap.get(qqPlan.PlanID).GroupNumber;
                        if(opp.Type.equals('Renewal')){
                            if(qqPlan.Type!=null){
                                if(qqPlan.Type.equals('New')){
                                  if(qqPlan.GroupNumber!=null){
                                    qqPlan.ChangeType = 'Benefit Change';
                                  }else{
                                    qqPlan.ChangeType = 'New';  
                                  }// Changing to Null as Venkat Request from 'New';
                                }
                                if(qqPlan.Type.equals('Update')){
                                    qqPlan.ChangeType = 'Benefit Change';
                                }
                                if(qqPlan.Type.equals('Existing')){
                                    qqPlan.ChangeType = 'Renewal';
                                }
                                if(qqPlan.Type.equals('Discontinue')){
                                    qqPlan.ChangeType = null;
                                }
                            }
                            
                                     
                        }
                        if(opp.Type.equals('Change')){
                            if(qqPlan.Type!=null){
                                if(qqPlan.Type.equals('New')){
                                    if(qqPlan.GroupNumber!=null){
                                    qqPlan.ChangeType = 'Benefit Change';
                                  }else{
                                    qqPlan.ChangeType = 'New';  
                                  }
                                }
                                if(qqPlan.Type.equals('Update')){
                                    qqPlan.ChangeType = 'Benefit Change';
                                }
                                if(qqPlan.Type.equals('Existing')){
                                    qqPlan.ChangeType = null;
                                }
                                //qqPlan.Discontinued = false;
                                if(qqPlan.Type.equals('Discontinue')){
                                    qqPlan.ChangeType = null;
                                    //qqPlan.Discontinued = true;
                                }
                            }
                        }
                        // To send changetype for change RFP flow - PC-8100
                        if(opp.Type.equals('Change')){
                            qqPlan.ChangeType = chngeOppChangeType;
                        }
                    }
              }
          }
      }
    
        P2EwPegaService.QQProposal qqProposal = new P2EwPegaService.QQProposal(qqAccount, qqOpportunity, plansList);
        qqProposal.TermAndTransfer=ttNodeLst;
        if(reqName!='IMPL'){
            if(cache.wizardType!=null && (cache.wizardType=='Re-Rate' || cache.wizardType=='Negotiation') && cache.originalCaseId!=null){
                qqProposal.CaseID = cache.originalCaseId;
            }
        }
        if(reqName.equals('Quick_Quote') || reqName.equals('EligibilityQQ')){
            qqReq = new P2EwQQRequest();
            qqReq.ServiceType = reqName;
            qqReq.Proposal = qqProposal;
        }
        if(reqName.equals('RFP') || reqName.equals('Change') || reqName.equals('New') || reqName.equals('Renewal')){
            rfpReq = new P2EwRFPRequest();
            rfpReq.ServiceType = 'RFP';
            rfpReq.SubType = reqName;
            rfpReq.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604            
            if(cache.wizardType!=null && cache.wizardType=='Re-Rate'){
                rfpReq.SubType = 'Re-Rate';
            }else if(cache.wizardType == 'Negotiation'){
                rfpReq.SubType = 'Update';
            }
            rfpReq.Proposal = qqProposal;
        }
        if(reqName.equals('IMPL')){
            implReq = new P2EwImplRequest();
            implReq.ServiceType = reqName;
            implReq.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604            
            if(opp.Type.equals('Renewal') || opp.Type.equals('Change')){
                implReq.SubType = opp.Type;
            }
            qqProposal.Contacts = qqCon;
            List<OpportunityLineItem> oliList = mapProdOLI.values();
            String pImplCaseId;
            for(OpportunityLineItem oli : oliList){
                if(pImplCaseId==null && oli.Par_Impl_case_Id_Hide__c != null){
                    pImplCaseId = oli.Par_Impl_case_Id_Hide__c;
                }
                /**** Added Re-IMPL Process Start****/
                system.debug('ParImplcaseId'+oli.Parent_Impl_Case_Id__c);
                if(rImplCaseId==null && oli.Par_Impl_case_Id_Hide__c != null && oli.Par_Impl_case_Id_Hide__c != oli.Parent_Impl_Case_Id__c){
                    rImplCaseId = oli.Parent_Impl_Case_Id__c;
                }
                /**** Re-IMPL Process End****/
            }
            if(oliList!=null && !oliList.isEmpty() && pImplCaseId!=null){
                qqProposal.caseId = pImplCaseId;
                qqProposal.RelatedIMCaseID = rImplCaseId; // Added for Re-IMPL Process
                for(OpportunityLineItem oli : oliList){
                    if(oli.Par_Impl_case_status_Hide__c != null){ //Changed from Parent_Impl_Case_Status__c
                        if(oli.Par_Impl_case_status_Hide__c != 'Resolved-Completed'){
                            implReq.SubType = 'Update';
                            break;
                        }else if(oli.Par_Impl_case_status_Hide__c == 'Resolved-Completed'){
                            implReq.SubType = 'Re-Rate';
                            break;
                        }
                     }
                        
                }
            }
            implReq.Implementation = qqProposal;
        }
        
        //Callout
        if(!Test.isRunningTest()){
            if(qqReq!=null){
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, qqReq.generate(),'Pega', username, reqName);
            }
            if(rfpReq!=null){
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, rfpReq.generate(),'Pega', username, reqName);
            }
            if(implReq!=null){
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, implReq.generate(),'Pega', username, reqName);
            }
        }else{
            if(reqName.equals('IMPL')) {
                httpRespBody = '{"Proposal":{"CaseStatus":"Pending-Review","CaseID":"P-2470"}}';
            } else if(!reqName.equals('RFP')){
                httpRespBody = '{"Proposal":{"CaseStatus":"New","CaseID":"PR-12121212"}}';
            } else {
                httpRespBody = '{"Proposal":{"CaseStatus":"Pending-Review","CaseID":"P-2470"}}';
            }
        }
        //Frame Response
        if(httpRespBody!=null){
            if(reqName.equals('RFP') || reqName.equals('Change') || reqName.equals('New') || reqName.equals('Renewal')){
                P2EwQQRFPResponse prodResp = null;
                try{
                    prodResp = P2EwQQRFPResponse.parse(httpRespBody);
                    String validateRespStr = prodResp.validateResponse();
                    if(validateRespStr != null){
                        system.debug('Valida:::::::'+validateRespStr);
                        //P2EhHelperClass.returnError(validateRespStr, '', 'Error');
                        if(!P2EhGlobalUtil.isBatch){
                            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,validateRespStr );
                            ApexPages.addMessage(myMsg);
                        }
                    }else{
                        //****PC-15314 - Update Special Auto Renewal flag to false once sent to PEGA successfully
                        if(opp.Type == 'Renewal'){
                            opp.Special_Auto_Renewal__c = false;
                            update opp;
                        }
                        return prodResp;
                    }
                }catch(JSONException e){
                     
                }catch(Exception e){
                    
                }
            }
            if(reqName.equals('IMPL')){
                P2EwImplResponse prodResp = null;
                try{
                    prodResp = P2EwImplResponse.parse(httpRespBody);
                    String validateRespStr = prodResp.validateResponse();
                    if(validateRespStr != null){
                        system.debug('Valida:::::::'+validateRespStr);
                        if(!P2EhGlobalUtil.isBatch){
                            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,validateRespStr );
                            ApexPages.addMessage(myMsg);
                        }
                    }else{
                        return prodResp;
                    }
                }catch(JSONException e){
                    
                }catch(Exception e){
                    
                }
            }
        }
        return null;
    }
    
    public String dateToStr(Date givenDate){
        String oppDuedateStr = ''; 
        if(givenDate!=null){
            oppDuedateStr = String.valueof(givenDate.year());
            if(givenDate.month()<10){
                oppDuedateStr += '0';
            }
            oppDuedateStr += String.valueof(givenDate.month());
            if(givenDate.day()<10){
                oppDuedateStr += '0';
            }
            oppDuedateStr += String.valueof(givenDate.day()); 
        }
        return oppDueDateStr;
    }
    
    public String PegaPhoneFormat(String Phone){
        if(Phone != NULL){
            Phone = Phone.Replace('+1', '');
            Phone = Phone.Replace('(', '');
            Phone = Phone.Replace(')', '');
            Phone = Phone.Replace('-','');
            Phone = Phone.Replace(' ','');
            return Phone;
        }else{
            return NULL;
        }
    }
    
    @TestVisible private List<P2EwPegaService.QQContacts> framePegaContact(){
        List<P2EwPegaService.QQContacts> qqCon = new List<P2EwPegaService.QQContacts>();
        for(Contact con: conList){
            P2EwPegaService.QQContacts qqContact = new P2EwPegaService.QQContacts();
            qqContact.ContactID = con.id;
            qqContact.ContactType = 'Renewal'; //con.Contact_Type__c;
            qqContact.LastName = con.LastName;
            qqContact.FirstName = con.FirstName;
            qqContact.CompanyName = acc.name;
            qqContact.TitleName = con.Title;
            qqContact.PhoneNumber = con.Phone;
            qqContact.Email = con.Email;
            qqContact.Fax = con.Fax;
            List<P2EwPegaService.QQAddressesList> addressesList;
            addressesList = new List<P2EwPegaService.QQAddressesList>();
            addressesList.add(new P2EwPegaService.QQAddressesList('Mailing', '', '', con.MailingStreet, con.MailingCity, con.MailingState, con.MailingPostalCode, con.County__c, con.MailingCountry));
            addressesList.add(new P2EwPegaService.QQAddressesList('Other', '', '', con.OtherStreet, con.OtherCity, con.OtherState, con.OtherPostalCode, con.County__c, con.OtherCountry));
            qqContact.AddressesList = addressesList;
            qqCon.add(qqContact);
        }
        return qqCon;
    }
    
    private P2EwPegaService.QQQAccount framePegaAccount(){
        List<P2EwPegaService.QQAddressList> addressList;
        P2EwPegaService.QQAccountExecutive qqAE;
        P2EwPegaService.QQAccountManager qqAM;
        P2EwPegaService.QQAccountManager[] qqAMs;
        User ae;
        try{
            addressList = new List<P2EwPegaService.QQAddressList>();
            addressList.add(new P2EwPegaService.QQAddressList(acc.BillingStreet, acc.BillingStreet, acc.BillingStreet, acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, acc.BillingCountry, 'Shipping', true));//This is main address in UI
            addressList.add(new P2EwPegaService.QQAddressList(acc.ShippingStreet, acc.ShippingStreet, acc.ShippingStreet, acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, P2EhPegaCallouts.mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, acc.ShippingCountry, 'Billing', false));//This is billing address in UI
            
            try{
                ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
            }catch(Exception exp){
                ae = null;
            }
            if(ae!=null){
                qqAE = new P2EwPegaService.QQAccountExecutive(ae.Name, ae.Email);
                qqAE.ExternalID = ae.Username;
                qqAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }else{
                qqAE = new P2EwPegaService.QQAccountExecutive('No AE assigned','');
            }
            User am;
            try{
                am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
            }catch(Exception exp){
                am = null;
            }
            qqAMs = new List<P2EwPegaService.QQAccountManager>();
            if(am!=null){
                qqAM = new P2EwPegaService.QQAccountManager(am.Name, am.Email);
                qqAM.ExternalID = am.Username;
                qqAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }else{
                qqAM = new P2EwPegaService.QQAccountManager ('No AM assigned','');
            }
        }catch(Exception e){
                        
            return null;
        }
        
        List<P2EwPegaService.QQNAIC> naicLst = new List<P2EwPegaService.QQNAIC>();      
        
        P2EwPegaService.QQQAccount qqAccount = new P2EwPegaService.QQQAccount();
        qqAccount.AccountID = acc.Id;
        qqAccount.NumberOfEmployees = acc.NumberOfEmployees;
        qqAccount.NumberOfEligibleEmployees = integer.valueOf(acc.Number_of_Eligible_Employees__c);
        qqAccount.AccountExecutive = qqAE;
        qqAccount.AccountManager = qqAM;
        qqAccount.AddressList = addressList;
        qqAccount.AccountName = acc.Name;
        if(acc.ParentId != Null){
            qqAccount.ParentAccountID = acc.ParentId; //Added for PC-12835
            qqAccount.ParentName = [Select Id, Name From Account Where Id =: acc.ParentId].Name; //Added for PC-12835
        } 
        qqAccount.AccountNumber = acc.Account_Number__c;
        qqAccount.SitusState = acc.Situs_State__c;
        qqAccount.BidSpecification = acc.Bid_Specification__c;
        qqAccount.Affiliation = acc.Affiliation__c;
        qqAccount.AccountType = acc.Type;
        if(opp.Type.equals('New')){
            qqAccount.Type = 'New';
            qqAccount.PriorDeltaGroup = acc.Prior_Delta_Group__c;
        }else{
            qqAccount.Type = 'Existing';
            qqAccount.PriorDeltaGroup = false;
        }
        qqAccount.SubType = acc.Business_Type__c;
        qqAccount.DBA = acc.DBA_Name__c;
        qqAccount.SalesGrade = acc.Sales_Grade__c;
        qqAccount.TotalEmployees = acc.NumberOfEmployees;
        qqAccount.CompanyStatus = acc.Company_Status__c;
        qqAccount.IsPool = acc.Pool__c;
        qqAccount.IsExchange = acc.Is_Exchange__c;
        qqAccount.IsStateExchange = acc.State_Exchange__c; 
        qqAccount.IsMedicalPartner = acc.Medical_Partner__c;

        if(acc.NaicsCode!=null){
            naicLst.add(new P2EwPegaService.QQNAIC(acc.NaicsCode,acc.NaicsDesc));
            qqAccount.NAICList = naicLst;
        }else{
            naicLst.add(new P2EwPegaService.QQNAIC('unknown', 'unknown'));
            qqAccount.NAICList = naicLst;
        }
        return qqAccount;
    }
    
    @TestVisible private List<P2EwPegaService.QQGroupInfo> frameGroupInfo(String type){
        List<P2EwPegaService.QQGroupInfo> GroupInfoList = new List<P2EwPegaService.QQGroupInfo>();
        List<Contract> conList = new List<Contract>();
        if(type == 'Account'){
            conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c,Contract_End_Date__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where accountId =: acc.Id];
        }
        else{
             if(opp.type == 'Renewal'){
                if(Opp.Id != null){
                    conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c,Contract_End_Date__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: Opp.Id];
                }
            }
            if(opp.type == 'Change'){
                if(chngRenOppId != null){
                    conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c,Contract_End_Date__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: chngRenOppId];
                }
            }
        }
        
        for(Contract con : conList){
            if(con.Group_Number__c!=null){
                P2EwPegaService.QQGroupInfo qqGrp = new P2EwPegaService.QQGroupInfo();
                //PC-13770 Start
                //if(reqName == 'IMPL'){
                    Integer disCount=0;
                    if(!mapGroupOli.isEmpty() && mapGroupOli.get(con.Group_Number__c)!=null){
                        for(OpportunityLineItem olidis:mapGroupOli.get(con.Group_Number__c)){
                            if((olidis.Action__c=='Discontinue') || (olidis.Decision_Status__c=='Not - Sold' && olidis.Action__c=='New')){
                                disCount++;
                            }
                        }
                        system.debug('disCount'+disCount);
                        system.debug('mapGroupOli'+mapGroupOli);
                        if(mapGroupOli.isEmpty()==false && mapGroupOli.keyset().contains(con.Group_Number__c) && disCount==mapGroupOli.get(con.Group_Number__c).size()){
                            system.debug('into discontinue if');
                            qqGrp.IsGroupTerminate=true;
                        }else{
                            system.debug('into not discontinue if');
                            qqGrp.IsGroupTerminate=false;
                        }
                    }
                //}//13770 End
                qqGrp.GroupNumber = con.Group_Number__c;
                qqGrp.GroupName = con.Name;
                qqGrp.GroupType = null;
                qqGrp.SubGroupType = null;
                qqGrp.ContractTermFrom = dateToStr(con.startdate);
                qqGrp.ContractTermTo = dateToStr(con.enddate);
                qqGrp.ContractEndDate = dateToStr(con.Contract_End_Date__c);
                qqGrp.RenewalClause = String.valueOf(con.Renewal_clause__c);
                qqGrp.RenewalDate = dateToStr(con.Contractual_Renewal_Date__c);
                qqGrp.ContractTerm = Integer.valueOf(con.ContractTerm__c);
                qqGrp.UnderwrittenBy = con.Company_UW_the_Group__c;
                GroupInfoList.add(qqGrp);
            }
        }
        return GroupInfoList;
    }
    /***** Change By HCL MM *****/
    @TestVisible private P2EwPegaService.QQOpportunity framePegaOpportunity(){
        P2EwPegaService.QQOpportunity qqOpportunity = new P2EwPegaService.QQOpportunity();
        qqOpportunity.EventGroupName = opp.Name;
        qqOpportunity.Amount = opp.Amount;
        qqOpportunity.OpportunityID = opp.Id;
        Opportunity oppEffectiveDate=[select CloseDate from Opportunity where id=:opp.Id];
        qqOpportunity.effectiveDate = oppEffectiveDate.CloseDate;

        qqOpportunity.Notes = opp.Opportunity_Notes__c;
        qqOpportunity.IsAutoRenewal = opp.AutoRenewal__c;
        qqOpportunity.AgeDistribution = null;
        qqOpportunity.NoteForOtherCredit = opp.Note_for_Other_Credit__c;
        qqOpportunity.Priority1 = opp.Priority_1__c;
        qqOpportunity.Priority2 = opp.Priority_2__c;
        qqOpportunity.Priority3 = opp.Priority_3__c;
        qqOpportunity.Priority4 = opp.Priority_4__c;
        qqOpportunity.Priority5 = opp.Priority_5__c;
        qqOpportunity.PriorDentalCoverage = opp.Prior_Dental_Coverage__c;
         if(quot!=null){
            if(quot.Sales_Notes__c != null){
                qqOpportunity.SalesNotes = EncodingUtil.base64Encode(Blob.valueOf(quot.Sales_Notes__c)); 
                List<P2EwPegaService.QQNotes> qqNotes = new List<P2EwPegaService.QQNotes>();
                /*
                for(Note notee : P2EhUserModeUtil.queryNote(quot.Id)){
                    qqNotes.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(notee.body)), notee.createdDate));
                }
                */
                
                /**** Modified for Notes Changes ****/
                for(Implementation_Notes__c notee : P2EhUserModeUtil.queryNote(quot.Id)){
                    qqNotes.add(new P2EwPegaService.QQNotes(EncodingUtil.base64Encode(Blob.valueOf(notee.Implementation_Notes__c)), notee.createdDate));
                }
                /**** Modified for Notes Changes ****/
                
                qqOpportunity.SalesNotesList = qqNotes;
            }
            /*if(quot.UW_Notes__c != null){//commented for UWNotes
            qqOpportunity.UWNotes = EncodingUtil.base64Encode(Blob.valueOf(quot.UW_Notes__c));
            } */ //commented for UWNotes
            qqOpportunity.StrategicInfo = opp.Strategic_Pricing_Recommendations__c;
            qqOpportunity.DueDate = dateToStr(quot.Date_Requested_by_AE__c);
            qqOpportunity.DateReqByGroup = dateToStr(quot.Date_Requested_by_Group__c);
            qqOpportunity.DeliveryType = quot.Delivery_Type__c;
            qqOpportunity.QuoteID = quot.Id;
            
            
            //qqOpportunity.HasClaimsExperience = quot.ReqClaimsExperience__c;  //Added for 2-way communication
            if(quot.ReqClaimsExperience__c){
                qqOpportunity.DueDateClaimsExperience = dateToStr(quot.Req_Claims_Experience_Date__c);
            }  
            
            qqOpportunity.HasCostSavingPG = quot.ReqCostSavingPG__c;
            if(quot.ReqCostSavingPG__c){
                qqOpportunity.DueDateCostSavingPG = dateToStr(quot.Req_Cost_Saving_PG_Date__c);
            }
            
            qqOpportunity.HasFeeAnalysis = quot.ReqFeeAnalysis__c;
            if(quot.ReqFeeAnalysis__c){
                qqOpportunity.DueDateFeeAnalysis = dateToStr(quot.Req_Fee_Analysis_Date__c);
            }
            //-----Added for PC-12407
              qqOpportunity.FeasibilityReview = quot.Req_Feasibility_Review__c;     
            if(quot.Req_Feasibility_Review__c){     
                qqOpportunity.DueDateFeasibilityReview = dateToStr(quot.Feasibility_Review_Expected_Date__c);
            }
            
            qqOpportunity.HasGeoAccess = quot.ReqGeoAccessReport__c;
            if(quot.ReqGeoAccessReport__c){
                qqOpportunity.DueDateGeoAccess = dateToStr(quot.Req_Geo_Access_Report_Date__c);
                
                 //------------------------ added for pc-11577                  
           qqOpportunity.GeoPPO= quot.PPO_Geo__c;
            qqOpportunity.GeoPPOAndPremier= quot.PPO_And_Premier_Geo__c;
            qqOpportunity.GeoPremier= quot.Premier_Geo__c;
            qqOpportunity.GeoDeltaCare= quot.DeltaCare_Geo__c;
            qqOpportunity.AllEmployees = quot.Combine_Employees__c;
            qqOpportunity.RetiredOnly = quot.Retired_Only__c;
            qqOpportunity.ActiveOnly = quot.Active_Only__c;
            qqOpportunity.OtherTypeofFilter = quot.Other_Type_of_Filter__c;         
            qqOpportunity.UrbanSuburbanRural = quot.Urban_Suburban_Rural__c;       
            qqOpportunity.GDOnly= quot.GD_Only__c; 
            qqOpportunity.SPOnly= quot.SP_Only__c;      
            qqOpportunity.GDSPCombined= quot.GD_SP_Combined__c;          
             qqOpportunity.GDandSP8Miles= quot.X2_GD_SP_in_8_miles__c;
             qqOpportunity.GDandSP10Miles= quot.X2_GD_SP_in_10_miles__c;            
             qqOpportunity.GDandSP15Miles= quot.X2_GD_SP_in_15_miles__c;
             qqOpportunity.GDSP10Milesand1SP15Miles= quot.X2_GD_in_10_miles_1_SP_in_15_miles__c;
              qqOpportunity.GDSP8MilesSpecialtyType= quot.GDSP8MilesSpecialtyType__c;
             qqOpportunity.GDSP10MilesSpecialtyType= quot.GDSP10MilesSpecialtyType__c;            
             qqOpportunity.GDSP15MilesSpecialtyType= quot.GDSP15MilesSpecialtyType__c;
             qqOpportunity.GD10Miles1SP15MilesSpecialtyType= quot.GD10Miles1SP15MilesSpecialtyType__c;
             qqOpportunity.UrbanSpecialtyType= quot.UrbanSpecialtyType__c;
             qqOpportunity.RuralSpecialtyType= quot.RuralSpecialtyType__c;
             qqOpportunity.SuburbanSpecialtyType= quot.SuburbanSpecialtyType__c;         
            qqOpportunity.Rural2Providers= quot.Rural_2_Providers__c; 
            qqOpportunity.Urban2Providers= quot.Urban_2_Providers__c; 
            qqOpportunity.Suburban2Providers= quot.Suburban_2_Providers__c; 
            qqOpportunity.GeoTemplateSelection= quot.Template_Selection__c;      
            qqOpportunity.GeoTemplateNotes= quot.Geo_Template_Notes__c;   
          //  qqOpportunity.State= quot.State__c;
            qqOpportunity.CBSA= quot.CBSA__c;
            qqOpportunity.County= quot.County__c;
            qqOpportunity.City= quot.City__c;
            qqOpportunity.Zip= quot.Zip__c;       
            qqOpportunity.CensusPasswordifApplicable= quot.Census_Password_if_Applicable__c;
            if(quot.Other_Notes__c != Null){ 
            qqOpportunity.OtherNotes = EncodingUtil.base64Encode(Blob.valueOf(quot.Other_Notes__c)); 
            } 
        
            }
            
            qqOpportunity.HasPG = quot.ReqPG__c;
            if(quot.ReqPG__c && (quot.PG_Standard_Custom__c=='Standard' || (quot.PG_Standard_Custom__c=='Custom'&& (acc.NumberOfEmployees != null && acc.NumberOfEmployees > 1000)))){
                qqOpportunity.DueDatePG = dateToStr(quot.Req_PG_Date__c);
            }
            qqOpportunity.PGType = quot.PG_Standard_Custom__c;
            
            qqOpportunity.HasRecruitmentPG = quot.ReqRecruitmentPG__c;
            if(quot.ReqRecruitmentPG__c){
                qqOpportunity.DueDateRecruitmentPG = dateToStr(quot.Req_Recruitment_PG_Date__c);
            }
            
            qqOpportunity.HasDisruptionAnalysis = quot.ReqDisruptionAnalysisReport__c;
            if(quot.ReqDisruptionAnalysisReport__c){
                qqOpportunity.DueDateDisruptionAnalysis = dateToStr(quot.Req_Disruption_Analysis_Report_Date__c);
                
                  //------------------------ added for pc-11577                           
            qqOpportunity.DisruptionPPOAndPremier = quot.PPO_And_Premier__c;   
            qqOpportunity.DisruptionDeltaCare = quot.DeltaCare_DA__c;
            qqOpportunity.CurrentCarrier= quot.Current_Carrier__c;
            qqOpportunity.CompetitorCarrier= quot.Competitor__c;
            qqOpportunity.CarrierRelatedNotes= quot.Carrier_related_notes__c;
            qqOpportunity.CompetitorRelatedNotes= quot.Competitor_related_notes__c;
            qqOpportunity.DATemplateSelection= quot.Template_SelectionDis__c;
            qqOpportunity.DATemplateNotes= quot.DA_Template_Notes__c; 
            }
            
            qqOpportunity.HasDeviationReview = quot.ReqDeviationReview__c;
            if(quot.ReqDeviationReview__c){
                 qqOpportunity.DueDateDeviationReview = dateToStr(quot.Req_Deviation_Review_Date__c);
            }
            
            /*qqOpportunity.HasNetworkSize = quot.ReqNetworkDiscount__c;
            if(quot.ReqNetworkDiscount__c){
                qqOpportunity.DueDateNetworkSize = dateToStr(quot.Req_Network_Discount_Date__c);
            }*/
            
            qqOpportunity.HasQuestionnaire = quot.ReqQuestionnaire__c;
            if(quot.ReqQuestionnaire__c){
                qqOpportunity.DueDateQuestionnaire = dateToStr(quot.Req_Questionnaire_Date__c);
            }
                        
            qqOpportunity.HasRepricing = quot.ReqRepricing__c;
            if(quot.ReqRepricing__c){
                qqOpportunity.DueDateRepricing = dateToStr(quot.Req_Repricing_Date__c);
            }
            
            qqOpportunity.HasDHMOPlanComparsion = quot.DHMO_Plan_Comparsion__c;
            if(quot.DHMO_Plan_Comparsion__c){
                qqOpportunity.DHMOPlanComparsionDate = dateToStr(quot.DHMO_Plan_Comparsion_Date__c);
            }
            
            qqOpportunity.ProviderUtilization = quot.Req_Provider_Utilization__c;
            if(quot.Req_Provider_Utilization__c){
                qqOpportunity.DueDateProviderUtilization = dateToStr(quot.Req_Provider_Utilization_Date__c);
            }
            
            qqOpportunity.HasNetworkDiscount = quot.Req_Network_Discounts__c;
            if(quot.Req_Network_Discounts__c){
                qqOpportunity.DueDateNetworkDiscount = dateToStr(quot.Req_Network_Discounts_Date__c);
            }
            
            qqOpportunity.ProviderCountsNWComp = quot.Req_Provider_Counts_NW_Comp__c;
            if(quot.Req_Provider_Counts_NW_Comp__c){
                qqOpportunity.DueDateProviderCountsNWComp = dateToStr(quot.Req_Provider_Counts_NW_Comp_Date__c);
            }
            
            qqOpportunity.NetworkGrowthandTurnover = quot.Req_Network_Growth_and_Turnover__c;
            if(quot.Req_Network_Growth_and_Turnover__c){
                qqOpportunity.DueDateNetworkGrowthandTurnover = dateToStr(quot.Req_Network_Growth_and_Turnover_Date__c);
            }
            
            qqOpportunity.AdhocProviderReport = quot.Req_Adhoc_Provider_Report__c;
            if(quot.Req_Adhoc_Provider_Report__c){
                qqOpportunity.DueDateAdhocProviderReport = dateToStr(quot.Req_Adhoc_Provider_Report_Date__c);
            }
            
            qqOpportunity.FinancialExperience = quot.Req_Financial_Experience__c;
            if(quot.Req_Financial_Experience__c){
                qqOpportunity.DueDateFinancialExperience = dateToStr(quot.Req_Financial_Experience_Date__c);
            }
            
            qqOpportunity.NetworkUtilization = quot.Req_Network_Utilization__c;
            if(quot.Req_Network_Utilization__c){
                qqOpportunity.DueDateNetworkUtilization = dateToStr(quot.Req_Network_Utilization_Date__c);
            }
            
            qqOpportunity.MaximumReport = quot.Req_Maximum_Report__c;
            if(quot.Req_Maximum_Report__c){
                qqOpportunity.DueDateMaximumReport = dateToStr(quot.Req_Maximum_Report_Date__c);
            }
            
            qqOpportunity.ExecutiveSummary = quot.Req_Executive_Summary__c;
            if(quot.Req_Executive_Summary__c){
                qqOpportunity.DueDateExecutiveSummary = dateToStr(quot.Req_Executive_Summary_Date__c);
            }
            
            qqOpportunity.ActuarialAdhocReport = quot.Req_Actuarial_Adhoc_Report__c;
            if(quot.Req_Actuarial_Adhoc_Report__c){
                qqOpportunity.DueDateActuarialAdhocReport = dateToStr(quot.Req_Actuarial_Adhoc_Report_Date__c);
            }
            /*
            qqOpportunity.DHMOFinancial = quot.Req_DHMO_Financial__c;
            if(quot.Req_DHMO_Financial__c){
                qqOpportunity.DueDateDHMOFinancial = dateToStr(quot.Req_DHMO_Financial_Date__c);
            }
            
            qqOpportunity.DHMOUtilization = quot.Req_DHMO_Utilization__c;
            if(quot.Req_DHMO_Utilization__c){
                qqOpportunity.DueDateDHMOUtilization = dateToStr(quot.Req_DHMO_Utilization_Date__c);
            }
            */
             //Added for 2-way communication 
            qqOpportunity.DHMOUtilizationFinancial = quot.Req_DHMO_Utilization__c;
            if(quot.Req_DHMO_Utilization__c){
                qqOpportunity.DHMOUtilizationFinancialDueDate = dateToStr(quot.Req_DHMO_Utilization_Date__c);
            }
            
            qqOpportunity.StateFederalPrograms = quot.Req_State_Federal_Programs__c;
            if(quot.Req_State_Federal_Programs__c){
                qqOpportunity.StateFederalProgramsDueDate = dateToStr(quot.State_Federal_Programs_Date__c);
            }
            
            qqOpportunity.D2CAdhocRequest = quot.Req_D2C_Adhoc_Request__c;
            if(quot.Req_D2C_Adhoc_Request__c){
                qqOpportunity.D2CAdhocRequestDueDate = dateToStr(quot.D2C_Adhoc_Request_Date__c);
            }            
            //Till here
            qqOpportunity.HasForm5500 = quot.Req_Form_5500__c;      
            if(quot.Req_Form_5500__c){      
                qqOpportunity.DueDateForm5500= dateToStr(quot.Req_Form_5500_Date__c);
                qqOpportunity.GroupNumber = quot.Group_Number__c;       
                qqOpportunity.DivisionNumber = quot.Division_Number__c;     
                qqOpportunity.Form5500StartDate = dateToStr(quot.Form_5500_Beginning_Period__c);        
                qqOpportunity.Form5500EndDate = dateToStr(quot.Form_5500_Ending_Period__c);     
                //qqOpportunity.ContractStartDate = dateToStr(quot.Contract_Beginning_Period__c);     
                //qqOpportunity.ContractEndDate = dateToStr(quot.Contract_Ending_Period__c);       
            }       
            
                                  
            if(doclist.size()>0){
                for(Document_Info__c doc:doclist){
                    if(doc.Document_Type__c=='Claims Experience'){                        
                        qqOpportunity.ClaimsExperienceNotes = doc.Notes__c;
                    }  
                    else if(doc.Document_Type__c=='Cost Saving PG'){                                    
                        qqOpportunity.CostSavingPGNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Fee Analysis'){                                                    
                        qqOpportunity.FeeAnalysisNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Geo Access Report'){                        
                        qqOpportunity.GeoAccessNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Performance Guarantee'){                        
                        qqOpportunity.PGNotes = doc.Notes__c;                        
                    }
                    else if(doc.Document_Type__c=='Recruitment PG'){                        
                        qqOpportunity.RecruitmentPGNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Disruption Analysis'){                        
                        qqOpportunity.DisruptionAnalysisNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Benefit Deviation'){                        
                        qqOpportunity.DeviationReviewNotes = doc.Notes__c;
                    }
                    /*else if(doc.Document_Type__c=='Network Size'){                        
                        qqOpportunity.NetworkSizeNotes = doc.Notes__c;
                    }*/
                    else if(doc.Document_Type__c=='Questionnaire'){                        
                        qqOpportunity.QuestionnaireNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Claims Re-Pricing'){                          
                        qqOpportunity.RepricingNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='DHMO Plan Comparsion'){                        
                        qqOpportunity.DHMOPlanComparsionNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Provider Utilization'){                        
                        qqOpportunity.ProviderUtilizationNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Network Discounts'){                        
                        qqOpportunity.NetworkDiscountNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Provider Counts NW Comp'){                        
                        qqOpportunity.ProviderCountsNWCompNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Network Growth and Turnover'){                        
                        qqOpportunity.NetworkGrowthandTurnoverNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Adhoc Provider Report'){                        
                        qqOpportunity.AdhocProviderReportNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Financial Experience'){                        
                        qqOpportunity.FinancialExperienceNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Network Utilization'){                        
                        qqOpportunity.NetworkUtilizationNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Maximum Report'){                        
                        qqOpportunity.MaximumReportNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Executive Summary'){                        
                        qqOpportunity.ExecutiveSummaryNotes = doc.Notes__c;
                    }
                    /* else if(doc.Document_Type__c=='DHMO Financial'){                        
                        qqOpportunity.DHMOFinancialNotes = doc.Notes__c;
                    }*/
                    else if(doc.Document_Type__c=='DHMO Utilization/Financial'){  //Updated the document type value as part of 2-way                       
                        qqOpportunity.DHMOUtilizationFinancialNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='State/Federal Programs'){                        
                        qqOpportunity.StateFederalProgramsNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='D2C Adhoc Request'){                        
                        qqOpportunity.D2CAdhocRequestNotes = doc.Notes__c;
                    }//Till here
                    else if(doc.Document_Type__c=='Actuarial Adhoc Report'){                        
                        qqOpportunity.ActuarialAdhocReportNotes = doc.Notes__c;
                    }
                    else if(doc.Document_Type__c=='Form 5500'){                             
                        qqOpportunity.Form5500Notes = doc.Notes__c; 
                       
                    }
                    // --------Added for PC-12407
                     else if(doc.Document_Type__c=='Feasibility Review'){                                   
                        qqOpportunity.FeasibilityReviewExpectedNotes= doc.Notes__c;             
                    }
                }
             }
            /*qqOpportunity.HasNetworkSize= quot.ReqNetworkDiscount__c;  // network size added as part of 9330
            qqOpportunity.DueDateNetworkSize = dateToStr(quot.Req_Network_Discount_Date__c);
            qqOpportunity.NetworkSizeNotes = quot.Network_Discount_Expected_Notes__c;
            */
        }
        //CreditDetails
        List<P2EwPegaService.QQCreditDetails> qqCreditDetails = new List<P2EwPegaService.QQCreditDetails>();
        /* Added for 2-way Communication */
        List<Credit__c> creditList = [SELECT Id,Name,Account__c,Frequency__c,Granted_Amount__c,Opportunity__c,PEPM_or_Dollar__c,Requested_Amount__c,Sales_Notes__c,Status__c,Type_of_Credit__c,UW_Notes__c FROM Credit__c Where Opportunity__c=:opp.Id];
        for(Credit__c cr:creditList){
            String Amount;
            String GrantedAmount;
            if(cr.Type_of_Credit__c == 'Other credits'){
                cr.Type_of_Credit__c = 'Others';
            }
            if(cr.Requested_Amount__c !=null){
                Amount = String.valueOf(cr.Requested_Amount__c);
            }
            if(cr.Granted_Amount__c !=null){
                GrantedAmount = String.valueOf(cr.Granted_Amount__c);
            }
            qqCreditDetails.add(new P2EwPegaService.QQCreditDetails(cr.Id, cr.Type_of_Credit__c, cr.PEPM_or_Dollar__c, Amount, GrantedAmount, cr.Frequency__c, cr.Sales_Notes__c,cr.UW_Notes__c));    
        }
        /* Till Here */     
                                                  
        if(qqCreditDetails.size() > 0){
            qqOpportunity.CreditsCheck = true;
            qqOpportunity.CreditDetails = qqCreditDetails;
        }else{
            qqOpportunity.CreditsCheck = false;
            qqOpportunity.CreditDetails = null;
        }
        
        //GroupNumbers
        List<P2EwPegaService.QQRequestedGroupNums> qqRequestedGroupNums = new List<P2EwPegaService.QQRequestedGroupNums>();
        if(opp.Description != null){
            for(String grpNbr : opp.Description.split(',')){
                P2EwPegaService.QQRequestedGroupNums qqGrpNum = new P2EwPegaService.QQRequestedGroupNums();
                qqGrpNum.GroupNumber = grpNbr;
                qqRequestedGroupNums.add(qqGrpNum);
            }
        }
        qqOpportunity.RequestedGroupNums = qqRequestedGroupNums;
        
        //Broker
        List<OpportunityContactRole__c> OCRList;
        List<P2EwPegaService.QQBroker> qqBrokers = new List<P2EwPegaService.QQBroker>();
        
        try{
            OCRList = [select Id, contact__c,Contact__r.AccountId, Contact__r.Account.Name, Admin_Type__c, Current_Commission_Type__c,Commission_Requested_Type__c, CommissionReqeusted__c, Current_Comission__c,Additional_Commision__c,Producer_Role__c,
                Contact__r.Account.Broker_Number__c, Contact__r.Account.BillingStreet, Contact__r.Account.BillingCity, 
                Contact__r.Account.BillingState, Contact__r.Account.BillingCountry, Contact__r.Account.BillingPostalCode, 
                Contact__r.Account.ShippingStreet, Contact__r.Account.ShippingCity, 
                Contact__r.Account.ShippingState, Contact__r.Account.ShippingCountry, Contact__r.Account.ShippingPostalCode, 
                Contact__r.Account.Phone, Contact__r.Account.Fax, Contact__r.Account.Broker_Type__c, Contact__r.Account.Company_Email__c, Contact__r.Account.RecordType.Name from OpportunityContactRole__c where 
                Contact__r.Account.RecordType.Name = 'Producer Firm' and Opportunity__c =: opp.Id];
            
            for(OpportunityContactRole__c OCR : OCRList){
                P2EwPegaService.QQCommission com;
              
                P2EwPegaService.QQBroker qqBroker = new P2EwPegaService.QQBroker();
                qqBroker.BrokerID = OCR.Contact__r.Account.Broker_Number__c;
             /*   Contact objContact=[select name from contact where id=:ocr.contact__c];
                system.debug('::::::'+objContact.name);
                system.debug('a::::::'+ocr.contact__c);*/
               qqBroker.BrokerName = OCR.Contact__r.Account.Name;
            // qqBroker.BrokerName = objContact.name; 
                qqBroker.Type = OCR.Contact__r.Account.Broker_Type__c; 
                qqBroker.ProducerRole = OCR.Producer_Role__c;    
                 //commission
                if(OCR.Current_Comission__c != null){
                    totalCommission += OCR.Current_Comission__c;           
                }
                com = new P2EwPegaService.QQCommission(OCR.Current_Commission_Type__c,OCR.Commission_Requested_Type__c,OCR.CommissionReqeusted__c,OCR.Current_Comission__c,OCR.Additional_Commision__c);   //updated for 2-way communication
                qqBroker.Commission = com;   
                if(OCR.Current_Commission_Type__c == 'Unknown' && OCR.Commission_Requested_Type__c =='Unknown'){    //Added for 2-way communication
                    qqBroker.Commission = null;
                }//Till Here                           
                P2EwPegaService.QQAddressList address = new P2EwPegaService.QQAddressList(OCR.Contact__r.Account.BillingStreet, OCR.Contact__r.Account.BillingStreet, OCR.Contact__r.Account.BillingStreet, OCR.Contact__r.Account.BillingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, mapStateStateCode.get(OCR.Contact__r.Account.BillingState), OCR.Contact__r.Account.BillingPostalCode, OCR.Contact__r.Account.BillingCountry, 'Shipping', true);//this is main address in UI
                qqBroker.Address = address;
                qqBrokers.add(qqBroker);
            }
              system.debug('tcomm'+totalCommission);
            qqOpportunity.Broker = qqBrokers;
        }catch(Exception e){
            
        }
        
        //Census
        List<P2EwPegaService.QQCensus> Census = new List<P2EwPegaService.QQCensus>();
        try{
            List<DD_Census_Summary__c> lstCensus = Database.Query(P2EhUtility.getQuery('DD_Census_Summary__c') + ' Where Related_Opportunity__c = \'' +opp.Id+ '\'');
            for(DD_Census_Summary__c cen: lstCensus){
                P2EwPegaService.QQCensus wCen = new P2EwPegaService.QQCensus(Integer.valueOf(cen.Number_Of_Enrollees__c), Null, cen.Zip_Code__c);
                Census.add(wCen);
            }
            qqOpportunity.Census = Census;
        }catch(Exception e){
            
        }
        return qqOpportunity;
    }
    public P2EwOnyxConversionResponse ConversionCaseCreation(list<case> caseId){
        
           system.debug('==entered into conversion');
    CaseComment sal;
    set<id> ctt=new set<id>();
        case cat=[select id,Due_Date__c,Effective_Date__c,ClosedAdhoc__c,ONYX_Incident_Id__c,Is_Impl_Initiated__c ,Description,Type,Change_Type__c,Change_SubType__c,Account.Pool__c from case where id in:caseId limit 1];
        P2EwPegaService.OCROnyxConversion OCRC = new P2EwPegaService.OCROnyxConversion();
        OCRC.OnyxAccountID = acc.ONYX_Account_Id__c;
      
        OCRC.IncidentID = cat.ONYX_Incident_Id__c ;
       
        OCRC.SFDCAccountID = acc.id;
      //  OCRC.IncidentID=opp.ONYX_IncidentId__c;
       // OCRC.Stage=opp.StageName;
        OCRC.Stage=cat.ClosedAdhoc__c;
        OCRC.SFDCNotes=cat.Description;
        OCRC.DueDate = dateToStr(cat.Due_Date__c);
        OCRC.EffectiveDate =dateToStr(cat.Effective_Date__c);
     
       // OCRC.GroupInfo=OCRGrp;
        
     P2EwOnyxConversionRequest OCR = new P2EwOnyxConversionRequest();
     
     //if(cat.Account.Pool__c==false){
        OCR.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604     
        OCR.ServiceType = 'ONYX';
        OCR.SubType = cat.Type;
         if(cat.Change_Type__c == 'Administrative'){
            OCR.ChangeTypeMode = 'Admin';
        }else if(cat.Change_Type__c == 'Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'Rate';
        }else if(cat.Change_Type__c == 'Non Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'NonRate';
        }
        //OCR.ChangeTypeMode=cat.Change_Type__c;
        OCR.ChangeSubType=cat.Change_SubType__c;
        OCR.OnyxConversion=OCRC; 
          
       // }
        
        //Commented for time being .
        /*else{
        OCR.ServiceType = 'Pool';
        OCR.SubType = cat.Type;
         if(cat.Change_Type__c == 'Administrative'){
            OCR.ChangeTypeMode = 'Admin';
        }else if(cat.Change_Type__c == 'Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'Rate';
        }else if(cat.Change_Type__c == 'Non Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'NonRate';
        }
        //OCR.ChangeTypeMode=cat.Change_Type__c;
        OCR.ChangeSubType=cat.Change_SubType__c;
        OCR.OnyxConversion=OCRC;
       
        }  */   
        
        //Case
           
        P2EwPegaService.QQSFDCCase qqCase = new P2EwPegaService.QQSFDCCase();
        qqCase.CaseID = cat.Id;
        OCRC.SFDCCase = qqCase;
        
        //Account 
        List<P2EwPegaService.QQAddressList> addressList;
        P2EwPegaService.QQAccountExecutive qqAE;
        P2EwPegaService.QQAccountManager qqAM;
        P2EwPegaService.QQAccountManager[] qqAMs;
        User ae;
        try{
            addressList = new List<P2EwPegaService.QQAddressList>();
            addressList.add(new P2EwPegaService.QQAddressList(acc.BillingStreet, acc.BillingStreet, '', acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, acc.BillingCountry, 'Billing', true));
            addressList.add(new P2EwPegaService.QQAddressList(acc.ShippingStreet, acc.ShippingStreet, '', acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, acc.ShippingCountry, 'Shipping', false));
            
            try{
                if(acc.Account_Executive__c != Null)
                    ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
            }
            catch(Exception exp){
                ae = null;
            }
            if(ae!=null){
                qqAE = new P2EwPegaService.QQAccountExecutive(ae.Name, ae.Email);
                qqAE.ExternalID = ae.Username;
                qqAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                qqAE = new P2EwPegaService.QQAccountExecutive('No AE assigned','');
            }
            User am;
            try{
                if(acc.Account_Manager__c != Null)
                    am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
            }
            catch(Exception exp){
                am = null;
            }
            qqAMs = new List<P2EwPegaService.QQAccountManager>();
            if(am!=null){
                qqAM = new P2EwPegaService.QQAccountManager(am.Name, am.Email);
                qqAM.ExternalID = am.Username;
                qqAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                qqAM = new P2EwPegaService.QQAccountManager ('No AM assigned','');
            }
            //qqAMs.add(qqAM);
        }catch(Exception e){
            if(!isbatch){
            if(ApexPages.currentPage() != null){
              //  P2EhHelperClass.returnError('Callout Failed due to insufficient data. Please check if all the required fields are populated.', e.getMessage(), 'Error');
            }}else{if(ApexPages.currentPage() != null){
                System.debug('Callout Failed due to insufficient data. Please check if all the required fields are populated.' + e.getMessage() + 'Error');                        
            }}
        }
        
        List<P2EwPegaService.QQNAIC> naicLst = new List<P2EwPegaService.QQNAIC>();      
        

        P2EwPegaService.QQQAccount qqAccount = new P2EwPegaService.QQQAccount();
        qqAccount.AccountID = acc.Id;
        qqAccount.NumberOfEmployees = acc.NumberOfEmployees;
        qqAccount.NumberOfEligibleEmployees = integer.valueOf(acc.Number_of_Eligible_Employees__c);
        qqAccount.AccountExecutive = qqAE;
        qqAccount.AccountManager = qqAM;
        qqAccount.AddressList = addressList;
        qqAccount.SICCode = acc.Sic;
        qqAccount.AccountName = acc.Name;
        if(acc.ParentId != Null){
            qqAccount.ParentAccountID = acc.ParentId; //Added for PC-12835
            qqAccount.ParentName = [Select Id, Name From Account Where Id =: acc.ParentId].Name; //Added for PC-12835
        }       
        qqAccount.SICCode = acc.Sic;
        qqAccount.AccountNumber = acc.Account_Number__c;
        qqAccount.SitusState = acc.Situs_State__c;
        qqAccount.BidSpecification = acc.Bid_Specification__c;
        qqAccount.Affiliation = acc.Affiliation__c;
        //qqAccount.AccountType = acc.Type;
        if(acc.Pool__c == True){
            qqAccount.AccountType = 'Pool';
        }    
        else if(acc.Is_Exchange__c == True){
            qqAccount.AccountType = 'Exchange';
        }     
        else{
            qqAccount.AccountType = 'Commercial';
        }
         if(opp.Type.equals('New')){
            qqAccount.Type = 'New';
            qqAccount.PriorDeltaGroup = acc.Prior_Delta_Group__c;
        }else{
            qqAccount.Type = 'Existing';
            qqAccount.PriorDeltaGroup = false;
        }
        qqAccount.SubType = acc.Business_Type__c;
        qqAccount.DBA = acc.DBA_Name__c;
        qqAccount.SalesGrade = acc.Sales_Grade__c;
        qqAccount.TotalEmployees = acc.NumberOfEmployees;
        qqAccount.CompanyStatus = acc.Company_Status__c;

        qqAccount.IsPool = acc.Pool__c;
        qqAccount.IsExchange = acc.Is_Exchange__c;
        qqAccount.IsStateExchange = acc.State_Exchange__c; 
        qqAccount.IsMedicalPartner = acc.Medical_Partner__c;
        
        /*if(acc.NAICLookup__c!=null){
            naicLst.add(new P2EwPegaService.QQNAIC(acc.NAICLookup__r.NAIC__c.split('-')[0], acc.NAICLookup__r.NAIC__c.split('-')[1]));
            qqAccount.NAICList = naicLst;
        }        
        else{
            naicLst.add(new P2EwPegaService.QQNAIC('unknown', 'unknown'));
            qqAccount.NAICList = naicLst;
        }*/
        
        if(acc.NaicsCode!=null){
            naicLst.add(new P2EwPegaService.QQNAIC(acc.NaicsCode, acc.NaicsDesc));
            qqAccount.NAICList = naicLst;
        }        
        else{
            naicLst.add(new P2EwPegaService.QQNAIC('unknown', 'unknown'));
            qqAccount.NAICList = naicLst;
        }
        qqAccount.GroupInfo = frameGroupInfo('Account');
        /*qqAccount.GroupInfo = new List<P2EwPegaService.QQGroupInfo>();
        for(Contract con: [Select Id, Group_Number__c, Name, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: Opp.Id]){
            if(con.Group_Number__c!=null){
                P2EwPegaService.QQGroupInfo OCRGrp= new P2EwPegaService.QQGroupInfo();
                OCRGrp.GroupNumber = con.Group_Number__c;
                OCRGrp.GroupName = con.Name;
                qqAccount.GroupInfo.add(OCRGrp);
                //OCRC.GroupInfo= OCRGrp;
            }
        }*/
        OCRC.Account = qqAccount;
        
        //Opportunity
        P2EwPegaService.QQOpportunity qqOpportunity = new P2EwPegaService.QQOpportunity();
        qqOpportunity.Amount = opp.Amount;
        qqOpportunity.OpportunityID = opp.Id;
        qqOpportunity.Notes = opp.Opportunity_Notes__c;
        qqOpportunity.IsAutoRenewal = opp.AutoRenewal__c;
        qqOpportunity.OpportunityType=opp.Type;
        if(opp.No_of_Enrollees__c!=null){
        qqOpportunity.EligiblePrimaryEnrollees=opp.No_of_Enrollees__c;}
        if(opp.Eligible_Primary_Enrollees__c!=null){
        qqOpportunity.TotalPrimaryEnrollees= integer.valueof(opp.Eligible_Primary_Enrollees__c);}
        
        
        
        // Broker
        List<OpportunityContactRole__c> OCRList;
        List<P2EwPegaService.QQBroker> qqBrokers = new List<P2EwPegaService.QQBroker>();
        
        try{
            OCRList = [select Id, Contact__r.AccountId, Contact__r.Account.Name, Admin_Type__c, CommissionReqeusted__c, Current_Comission__c,Additional_Commision__c,Producer_Role__c,
                Contact__r.Account.Broker_Number__c, Contact__r.Account.BillingStreet, Contact__r.Account.BillingCity, 
                Contact__r.Account.BillingState, Contact__r.Account.BillingCountry, Contact__r.Account.BillingPostalCode, 
                Contact__r.Account.ShippingStreet, Contact__r.Account.ShippingCity, 
                Contact__r.Account.ShippingState, Contact__r.Account.ShippingCountry, Contact__r.Account.ShippingPostalCode, 
                Contact__r.Account.Phone, Contact__r.Account.Fax, Contact__r.Account.Broker_Type__c, Contact__r.Account.Company_Email__c, Contact__r.Account.RecordType.Name from OpportunityContactRole__c where 
                Contact__r.Account.RecordType.Name = 'Producer Firm' and Opportunity__c =: opp.Id];
            
            for(OpportunityContactRole__c OC : OCRList){
                P2EwPegaService.QQCommission com;
              
                P2EwPegaService.QQBroker qqBroker = new P2EwPegaService.QQBroker();
                qqBroker.BrokerID = OC.Contact__r.Account.Broker_Number__c;
               /* Contact objContact=[select name from contact where id=:OC.contact__c];
                system.debug('::::::'+objContact.name);
                system.debug('abcde::::::'+oc.contact__c);
                
                 qqBroker.BrokerName = objContact.name; */
                qqBroker.BrokerName = OC.Contact__r.Account.Name;
                qqBroker.Type = OC.Contact__r.Account.Broker_Type__c;  
                qqBroker.ProducerRole = OC.Producer_Role__c;    
                if(OC.Current_Comission__c != null){
                    totalCommission += OC.Current_Comission__c;           
                }
                com = new P2EwPegaService.QQCommission(OC.Current_Commission_Type__c,OC.Commission_Requested_Type__c,OC.CommissionReqeusted__c,OC.Current_Comission__c,OC.Additional_Commision__c);
                qqBroker.Commission = com;
                qqBroker.Commission = com;
               
                //List<P2EwPegaService.QQAddressList> addressLst = new List<P2EwPegaService.QQAddressList>();
                P2EwPegaService.QQAddressList address = new P2EwPegaService.QQAddressList(OC.Contact__r.Account.BillingStreet, OC.Contact__r.Account.BillingStreet, '', OC.Contact__r.Account.BillingCity, PegaPhoneFormat(OC.Contact__r.Account.Fax), PegaPhoneFormat(OC.Contact__r.Account.Phone), OC.Contact__r.Account.Company_Email__c, mapStateStateCode.get(OC.Contact__r.Account.BillingState), OC.Contact__r.Account.BillingPostalCode, OC.Contact__r.Account.BillingCountry, 'Billing', true);
                //addressLst.add(new P2EwPegaService.QQAddressList(OCR.Contact__r.Account.ShippingStreet, OCR.Contact__r.Account.ShippingStreet, '', OCR.Contact__r.Account.ShippingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, mapStateStateCode(OCR.Contact__r.Account.ShippingState), OCR.Contact__r.Account.ShippingPostalCode, 'Shipping', false));
                qqBroker.Address = address;
                qqBrokers.add(qqBroker);
            }
              system.debug('tcomm11'+totalCommission);
            qqOpportunity.Broker = null;
        }catch(Exception e){
            qqOpportunity.Broker = null;
        }
        List<P2EwPegaService.QQCensus> Census = new List<P2EwPegaService.QQCensus>();
        List<DD_Census_Summary__c> lstCensus = new List<DD_Census_Summary__c> ([ select id,Number_Of_Enrollees__c,Zip_Code__c,Related_Opportunity__c  from  DD_Census_Summary__c Where Related_Opportunity__r.id =:opp.Id]);
        for(DD_Census_Summary__c cen: lstCensus){
            P2EwPegaService.QQCensus wCen = new P2EwPegaService.QQCensus(Integer.valueOf(cen.Number_Of_Enrollees__c), Null, cen.Zip_Code__c);
            Census.add(wCen);
        }
        qqOpportunity.Census = Census;
        OCRC.Opportunity = qqOpportunity;
            
           List<Contract> conList = new List<Contract>();
            if(opp.type == 'Renewal' && opp.Id != null){
                conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: Opp.Id];
            }
            if(opp.type == 'Change' && chngRenOppId != null){
                conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: chngRenOppId];
            }
            for(Contract con: conList){ 
                if(con.Group_Number__c!=null){
                    P2EwPegaService.OCRGroupInfo OCRGrp= new P2EwPegaService.OCRGroupInfo();
                    OCRGrp.GroupNumber = con.Group_Number__c;
                    OCRGrp.GroupName = con.Name;
                    
                    OCRC.GroupInfo= OCRGrp;
                }
            }
           
           
           //Task
           for(case cas:caseId){
           List<P2EwPegaService.OCROpenTasks> OCROpT = new List<P2EwPegaService.OCROpenTasks>();
           P2EwPegaService.OCROpenTasks OCRTask = new P2EwPegaService.OCROpenTasks();
           OCRTask.TaskID = cas.ONYX_TaskId__c;
           OCRTask.IncidentID = opp.ONYX_IncidentId__c; 
           OCRTask.TaskCategoryDesc = cas.Task_Type__c; 
           OCRTask.StatusDesc = cas.ONYX_Grammar__c;
           OCRTask.AssignedTo = cas.Source_AssignedTo__c;
           OCRTask.TaskTypeDesc = cas.ONYX_Financial__c;
           OCRTask.TaskDesc = cas.ONYX_Judgement__c;
           OCRTask.Notes = cas.Task_Notes__c;
           OCROpT.add(OCRTask);
           //OCRC.OpenTasks = OCROpT;
           system.debug('==creating task');
           }
           //Callout
        if(!Test.isRunningTest()){
            if(OCR!=null){
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, OCR.generate(),null,null,null);
                //httpRespBody = '{"Proposal":{"Plans": [{"PlanName":"PPO 10 - New Plan99","PlanID":"5232565016","RateSheets": [{"OriginalRates": [{"CurrentRate":77.0000,"ContractTypeCode":"08","ManualRate":77.0000,"TierName":"302"},{"CurrentRate":88.0000,"ContractTypeCode":"09","ManualRate":88.0000,"TierName":"302"},{"CurrentRate":99.0000,"ContractTypeCode":"17","ManualRate":99.0000,"TierName":"302"}]}]}],"CaseStatus":"Resolved-Completed","Opportunity":{"OpportunityName":"","Amount":0,"OpportunityID":"006K000000BMc2kIAD","DueDate":""},"Account":{"NumberOfEmployees":"6000","SitusState":"LA","SICCode":"3915","AddressList": [{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"},{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"}],"AccountNumber":"VERI002","AccountManager":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"AccountName":"Nathiya","AccountExecutive":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"}},"CaseID":"P-2937"}}';
            }
        }
        else{
                httpRespBody = '{"OnyxConversion":{"CaseID":"P-2470"}}';
            }
       
        //httpRespBody = '{"Proposal":{"CaseStatus":"Resolved-Completed","Opportunity":{"OpportunityName":"","Amount":0,"OpportunityID":"006K000000BMc2kIAD","DueDate":""},"Account":{"NumberOfEmployees":"5900","SitusState":"LA","SICCode":"3915","AddressList":[{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"},{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"}],"AccountNumber":"VERI002","AccountManager":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"AccountName":"Nathiya","AccountExecutive":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"NAICList":["339913"]},"CaseID":"P-2621"}}';
        //Frame Response
        P2EwOnyxConversionResponse OnyxResp = null;
        if(httpRespBody!=null){
            system.debug('--=httpRespBody'+httpRespBody);
                try{
                    OnyxResp = P2EwOnyxConversionResponse.parse(httpRespBody);
                   }
                   catch(JSONException e){
                    if(!isbatch){
                      //  P2EhHelperClass.returnError('Error Parsing the Response received. Bad Response received for EligibilityQQ Call', '', 'Error');
                    }else{
                        System.debug('Error Parsing the Response received. Bad Response received for EligibilityQQ Call' + 'Error');                     
                    }
                }catch(Exception e){
                    if(!isbatch){
                       // P2EhHelperClass.returnError('Exception while processing the response', '', 'Error');
                    }else{
                        System.debug('Exception while processing the response' + 'Error');                                         
                    }    
                }
                
                }system.debug('--=OnyxResp');
                return OnyxResp;        
     
    } 
    
public P2EwOnyxConversionResponse PoolCaseCreation(list<case> caseId){
    
       system.debug('==entered into Poolconversion');
CaseComment sal;
set<id> ctt=new set<id>();
    case cat=[select id,Due_Date__c,Effective_Date__c,ClosedAdhoc__c,ONYX_Incident_Id__c,Is_Impl_Initiated__c ,Description,Type,Change_Type__c,Change_SubType__c,Account.Pool__c from case where id in:caseId limit 1];
/*list<CaseComment> csc=new list<CaseComment>([SELECT Id,ParentId,CommentBody FROM CaseComment where ParentId!=null and CommentBody!=null]);
if(csc.size()>0){
for(CaseComment cco:csc){
if(cco.parentId==cat.id){
ctt.add(cco.parentId);

}}}
if(ctt.size()>0){
sal=[select id,CommentBody from CaseComment  where  parentId in:ctt Order by CreatedDate DESC limit 1];
system.debug('--sal'+sal);
}*/
        P2EwPegaService.OCROnyxConversion OCRC = new P2EwPegaService.OCROnyxConversion();
        OCRC.OnyxAccountID = acc.ONYX_Account_Id__c;
      
        OCRC.IncidentID = cat.ONYX_Incident_Id__c ;
       
        OCRC.SFDCAccountID = acc.id;
      //  OCRC.IncidentID=opp.ONYX_IncidentId__c;
       // OCRC.Stage=opp.StageName;
        OCRC.Stage=cat.ClosedAdhoc__c;
        OCRC.SFDCNotes=cat.Description;
        OCRC.DueDate = dateToStr(cat.Due_Date__c);
        OCRC.EffectiveDate =dateToStr(cat.Effective_Date__c);
     
       // OCRC.GroupInfo=OCRGrp;
        
     P2EwOnyxConversionRequest OCR = new P2EwOnyxConversionRequest();
     
     
        OCR.ServiceType = 'Pool';
        OCR.SubType = cat.Type;
        OCR.SFDCUserName = [select Id, Name, username from User where Id = :UserInfo.getUserId()].Name; //Added for PC-11604        
         if(cat.Change_Type__c == 'Administrative'){
            OCR.ChangeTypeMode = 'Admin';
        }else if(cat.Change_Type__c == 'Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'Rate';
        }else if(cat.Change_Type__c == 'Non Rate Impacting Changes'){
            OCR.ChangeTypeMode = 'NonRate';
        }
        //OCR.ChangeTypeMode=cat.Change_Type__c;
        OCR.ChangeSubType=cat.Change_SubType__c;
        OCR.OnyxConversion=OCRC; 
          
      
        
      
        
        //Case
           
        P2EwPegaService.QQSFDCCase qqCase = new P2EwPegaService.QQSFDCCase();
        qqCase.CaseID = cat.Id;
        OCRC.SFDCCase = qqCase;
        
        //Account 
        List<P2EwPegaService.QQAddressList> addressList;
        P2EwPegaService.QQAccountExecutive qqAE;
        P2EwPegaService.QQAccountManager qqAM;
        P2EwPegaService.QQAccountManager[] qqAMs;
        User ae;
        try{
            addressList = new List<P2EwPegaService.QQAddressList>();
            addressList.add(new P2EwPegaService.QQAddressList(acc.BillingStreet, acc.BillingStreet, '', acc.BillingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, mapStateStateCode.get(acc.BillingState), acc.BillingPostalCode, acc.BillingCountry, 'Billing', true));
            addressList.add(new P2EwPegaService.QQAddressList(acc.ShippingStreet, acc.ShippingStreet, '', acc.ShippingCity, PegaPhoneFormat(acc.Fax), PegaPhoneFormat(acc.Phone), acc.Company_Email__c, mapStateStateCode.get(acc.ShippingState), acc.ShippingPostalCode, acc.ShippingCountry, 'Shipping', false));
            
            try{
                ae = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Executive__c Limit 1];
            }
            catch(Exception exp){
                ae = null;
            }
            if(ae!=null){
                qqAE = new P2EwPegaService.QQAccountExecutive(ae.Name, ae.Email);
                qqAE.ExternalID = ae.Username;
                qqAE.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                qqAE = new P2EwPegaService.QQAccountExecutive('No AE assigned','');
            }
            User am;
            try{
                am = [Select Id, Name, Email, Username From User Where Id =: acc.Account_Manager__c Limit 1];
            }
            catch(Exception exp){
                am = null;
            }
            qqAMs = new List<P2EwPegaService.QQAccountManager>();
            if(am!=null){
                qqAM = new P2EwPegaService.QQAccountManager(am.Name, am.Email);
                qqAM.ExternalID = am.Username;
                qqAM.pyUserIdentifier = null; //Iteration 3 - Yet to Map
            }
            else{
                qqAM = new P2EwPegaService.QQAccountManager ('No AM assigned','');
            }
            //qqAMs.add(qqAM);
        }catch(Exception e){
            if(!isbatch){
            if(ApexPages.currentPage() != null){
              //  P2EhHelperClass.returnError('Callout Failed due to insufficient data. Please check if all the required fields are populated.', e.getMessage(), 'Error');
            }}else{if(ApexPages.currentPage() != null){
                System.debug('Callout Failed due to insufficient data. Please check if all the required fields are populated.' + e.getMessage() + 'Error');                        
            }}
        }
        
        List<P2EwPegaService.QQNAIC> naicLst = new List<P2EwPegaService.QQNAIC>();      
        

        P2EwPegaService.QQQAccount qqAccount = new P2EwPegaService.QQQAccount();
        qqAccount.AccountID = acc.Id;
        qqAccount.NumberOfEmployees = acc.NumberOfEmployees;
        qqAccount.NumberOfEligibleEmployees = integer.valueOf(acc.Number_of_Eligible_Employees__c);
        qqAccount.AccountExecutive = qqAE;
        qqAccount.AccountManager = qqAM;
        qqAccount.AddressList = addressList;
        qqAccount.SICCode = acc.Sic;
        qqAccount.AccountName = acc.Name;
        if(acc.ParentId != Null){
            qqAccount.ParentAccountID = acc.ParentId; //Added for PC-12835
            qqAccount.ParentName = [Select Id, Name From Account Where Id =: acc.ParentId].Name; //Added for PC-12835
        }    
        qqAccount.SICCode = acc.Sic;
        qqAccount.AccountNumber = acc.Account_Number__c;
        qqAccount.SitusState = acc.Situs_State__c;
        qqAccount.BidSpecification = acc.Bid_Specification__c;
        qqAccount.Affiliation = acc.Affiliation__c;
        //qqAccount.AccountType = acc.Type;
        if(acc.Pool__c == True){
            qqAccount.AccountType = 'Pool';
        }    
        else if(acc.Is_Exchange__c == True){
            qqAccount.AccountType = 'Exchange';
        }     
        else{
            qqAccount.AccountType = 'Commercial';
        }
        if(opp.Type.equals('New')){
            qqAccount.Type = 'New';
            qqAccount.PriorDeltaGroup = acc.Prior_Delta_Group__c;
        }else{
            qqAccount.Type = 'Existing';
            qqAccount.PriorDeltaGroup = false;
        }
        qqAccount.SubType = acc.Business_Type__c;
        qqAccount.DBA = acc.DBA_Name__c;
        qqAccount.SalesGrade = acc.Sales_Grade__c;
        qqAccount.TotalEmployees = acc.NumberOfEmployees;
        qqAccount.CompanyStatus = acc.Company_Status__c;

        qqAccount.IsPool = acc.Pool__c;
        qqAccount.IsExchange = acc.Is_Exchange__c;
        qqAccount.IsStateExchange = acc.State_Exchange__c; 
        qqAccount.IsMedicalPartner = acc.Medical_Partner__c;
        
        /*if(acc.NAICLookup__c!=null){
            naicLst.add(new P2EwPegaService.QQNAIC(acc.NAICLookup__r.NAIC__c.split('-')[0], acc.NAICLookup__r.NAIC__c.split('-')[1]));
            qqAccount.NAICList = naicLst;
        }        
        else{
            naicLst.add(new P2EwPegaService.QQNAIC('unknown', 'unknown'));
            qqAccount.NAICList = naicLst;
        }*/
        
        if(acc.NaicsCode!=null){
            naicLst.add(new P2EwPegaService.QQNAIC(acc.NaicsCode, acc.NaicsDesc));
            qqAccount.NAICList = naicLst;
        }        
        else{
            naicLst.add(new P2EwPegaService.QQNAIC('unknown', 'unknown'));
            qqAccount.NAICList = naicLst;
        }
        qqAccount.GroupInfo = frameGroupInfo('Account');
        /*qqAccount.GroupInfo = new List<P2EwPegaService.QQGroupInfo>();
        for(Contract con: [Select Id, Group_Number__c, Name, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: Opp.Id]){
            if(con.Group_Number__c!=null){
                P2EwPegaService.QQGroupInfo OCRGrp= new P2EwPegaService.QQGroupInfo();
                OCRGrp.GroupNumber = con.Group_Number__c;
                OCRGrp.GroupName = con.Name;
                qqAccount.GroupInfo.add(OCRGrp);
                //OCRC.GroupInfo= OCRGrp;
            }
        }*/
        OCRC.Account = qqAccount;
        
        //Opportunity
        P2EwPegaService.QQOpportunity qqOpportunity = new P2EwPegaService.QQOpportunity();
        qqOpportunity.Amount = opp.Amount;
        qqOpportunity.OpportunityID = opp.Id;
        qqOpportunity.Notes = opp.Opportunity_Notes__c;
        qqOpportunity.IsAutoRenewal = opp.AutoRenewal__c;
        qqOpportunity.OpportunityType=opp.Type;
        if(opp.No_of_Enrollees__c!=null){
        qqOpportunity.EligiblePrimaryEnrollees=opp.No_of_Enrollees__c;}
        if(opp.Eligible_Primary_Enrollees__c!=null){
        qqOpportunity.TotalPrimaryEnrollees= integer.valueof(opp.Eligible_Primary_Enrollees__c);}
        
        
        
        // Broker
        List<OpportunityContactRole__c> OCRList;
        List<P2EwPegaService.QQBroker> qqBrokers = new List<P2EwPegaService.QQBroker>();
        
        try{
            OCRList = [select Id, Contact__r.AccountId, Contact__r.Account.Name, Admin_Type__c,Current_Commission_Type__c,Commission_Requested_Type__c, CommissionReqeusted__c, Current_Comission__c,Additional_Commision__c,Producer_Role__c,
                Contact__r.Account.Broker_Number__c, Contact__r.Account.BillingStreet, Contact__r.Account.BillingCity, 
                Contact__r.Account.BillingState, Contact__r.Account.BillingCountry, Contact__r.Account.BillingPostalCode, 
                Contact__r.Account.ShippingStreet, Contact__r.Account.ShippingCity, 
                Contact__r.Account.ShippingState, Contact__r.Account.ShippingCountry, Contact__r.Account.ShippingPostalCode, 
                Contact__r.Account.Phone, Contact__r.Account.Fax, Contact__r.Account.Broker_Type__c, Contact__r.Account.Company_Email__c, Contact__r.Account.RecordType.Name from OpportunityContactRole__c where 
                Contact__r.Account.RecordType.Name = 'Producer Firm' and Opportunity__c =: opp.Id];
            
            for(OpportunityContactRole__c OC : OCRList){
                P2EwPegaService.QQCommission com;
              
                P2EwPegaService.QQBroker qqBroker = new P2EwPegaService.QQBroker();
                qqBroker.BrokerID = OC.Contact__r.Account.Broker_Number__c;
               /* Contact objContact=[select name from contact where id=:OC.contact__c];
                system.debug('::::::'+objContact.name);
                system.debug('abcde::::::'+oc.contact__c);
                
                 qqBroker.BrokerName = objContact.name; */
                qqBroker.BrokerName = OC.Contact__r.Account.Name;
                qqBroker.Type = OC.Contact__r.Account.Broker_Type__c;  
                qqBroker.ProducerRole = OC.Producer_Role__c;    
                if(OC.Current_Comission__c != null){
                    totalCommission += OC.Current_Comission__c;           
                }
                com = new P2EwPegaService.QQCommission(OC.Current_Commission_Type__c,OC.Commission_Requested_Type__c,OC.CommissionReqeusted__c,OC.Current_Comission__c,OC.Additional_Commision__c);
                qqBroker.Commission = com;
               
                //List<P2EwPegaService.QQAddressList> addressLst = new List<P2EwPegaService.QQAddressList>();
                P2EwPegaService.QQAddressList address = new P2EwPegaService.QQAddressList(OC.Contact__r.Account.BillingStreet, OC.Contact__r.Account.BillingStreet, '', OC.Contact__r.Account.BillingCity, PegaPhoneFormat(OC.Contact__r.Account.Fax), PegaPhoneFormat(OC.Contact__r.Account.Phone), OC.Contact__r.Account.Company_Email__c, mapStateStateCode.get(OC.Contact__r.Account.BillingState), OC.Contact__r.Account.BillingPostalCode, OC.Contact__r.Account.BillingCountry, 'Billing', true);
                //addressLst.add(new P2EwPegaService.QQAddressList(OCR.Contact__r.Account.ShippingStreet, OCR.Contact__r.Account.ShippingStreet, '', OCR.Contact__r.Account.ShippingCity, PegaPhoneFormat(OCR.Contact__r.Account.Fax), PegaPhoneFormat(OCR.Contact__r.Account.Phone), OCR.Contact__r.Account.Company_Email__c, mapStateStateCode(OCR.Contact__r.Account.ShippingState), OCR.Contact__r.Account.ShippingPostalCode, 'Shipping', false));
                qqBroker.Address = address;
                qqBrokers.add(qqBroker);
            }
              system.debug('tcomm11'+totalCommission);
            qqOpportunity.Broker = null;
        }catch(Exception e){
            qqOpportunity.Broker = null;
        }
        List<P2EwPegaService.QQCensus> Census = new List<P2EwPegaService.QQCensus>();
        List<DD_Census_Summary__c> lstCensus = new List<DD_Census_Summary__c> ([ select id,Number_Of_Enrollees__c,Zip_Code__c,Related_Opportunity__c  from  DD_Census_Summary__c Where Related_Opportunity__r.id =:opp.Id]);
        for(DD_Census_Summary__c cen: lstCensus){
            P2EwPegaService.QQCensus wCen = new P2EwPegaService.QQCensus(Integer.valueOf(cen.Number_Of_Enrollees__c), Null, cen.Zip_Code__c);
            Census.add(wCen);
        }
        qqOpportunity.Census = Census;
        OCRC.Opportunity = qqOpportunity;
            
           List<Contract> conList = new List<Contract>();
            if(opp.type == 'Renewal' && opp.Id != null){
                conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: Opp.Id];
            }
            if(opp.type == 'Change' && chngRenOppId != null){
                conList = [Select Id, Contractual_Renewal_Date__c,Company_UW_the_Group__c, Group_Number__c, Name, StartDate, EndDate, ContractTerm__c, Renewal_clause__c, Renewal_Opportunity__c From Contract Where Renewal_Opportunity__c =: chngRenOppId];
            }
            for(Contract con: conList){ 
                if(con.Group_Number__c!=null){
                    P2EwPegaService.OCRGroupInfo OCRGrp= new P2EwPegaService.OCRGroupInfo();
                    OCRGrp.GroupNumber = con.Group_Number__c;
                    OCRGrp.GroupName = con.Name;
                    
                    OCRC.GroupInfo= OCRGrp;
                }
            }
           
           
           //Task
           for(case cas:caseId){
           List<P2EwPegaService.OCROpenTasks> OCROpT = new List<P2EwPegaService.OCROpenTasks>();
           P2EwPegaService.OCROpenTasks OCRTask = new P2EwPegaService.OCROpenTasks();
           OCRTask.TaskID = cas.ONYX_TaskId__c;
           OCRTask.IncidentID = opp.ONYX_IncidentId__c; 
           OCRTask.TaskCategoryDesc = cas.Task_Type__c; 
           OCRTask.StatusDesc = cas.ONYX_Grammar__c;
           OCRTask.AssignedTo = cas.Source_AssignedTo__c;
           OCRTask.TaskTypeDesc = cas.ONYX_Financial__c;
           OCRTask.TaskDesc = cas.ONYX_Judgement__c;
           OCRTask.Notes = cas.Task_Notes__c;
           OCROpT.add(OCRTask);
           //OCRC.OpenTasks = OCROpT;
           system.debug('==creating task');
           }
           //Callout
        if(!Test.isRunningTest()){
            if(OCR!=null){
                httpRespBody = P2EhHttpHelper.httpCallout(headerMap, method, endPointURL, OCR.generate(),null,null,null);
                //httpRespBody = '{"Proposal":{"Plans": [{"PlanName":"PPO 10 - New Plan99","PlanID":"5232565016","RateSheets": [{"OriginalRates": [{"CurrentRate":77.0000,"ContractTypeCode":"08","ManualRate":77.0000,"TierName":"302"},{"CurrentRate":88.0000,"ContractTypeCode":"09","ManualRate":88.0000,"TierName":"302"},{"CurrentRate":99.0000,"ContractTypeCode":"17","ManualRate":99.0000,"TierName":"302"}]}]}],"CaseStatus":"Resolved-Completed","Opportunity":{"OpportunityName":"","Amount":0,"OpportunityID":"006K000000BMc2kIAD","DueDate":""},"Account":{"NumberOfEmployees":"6000","SitusState":"LA","SICCode":"3915","AddressList": [{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"},{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"}],"AccountNumber":"VERI002","AccountManager":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"AccountName":"Nathiya","AccountExecutive":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"}},"CaseID":"P-2937"}}';
            }
        }
        else{
                httpRespBody = '{"OnyxConversion":{"CaseID":"P-2470"}}';
            }
       
        //httpRespBody = '{"Proposal":{"CaseStatus":"Resolved-Completed","Opportunity":{"OpportunityName":"","Amount":0,"OpportunityID":"006K000000BMc2kIAD","DueDate":""},"Account":{"NumberOfEmployees":"5900","SitusState":"LA","SICCode":"3915","AddressList":[{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"},{"State":"Georgia","pyEmailAddress":"contact@quest.com","AddressDetails":"North Avene","Fax":"5563223","PhoneNumber":"(342) 334-3423","Zip":"40004","AddressLine1":"North Avene","AddressLine2":"","City":"Atlanta"}],"AccountNumber":"VERI002","AccountManager":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"AccountName":"Nathiya","AccountExecutive":{"Name":"Ruba Kesavamani","pyEmailAddress":"rubapriyadharsini.kesavamani@techmahindra.com"},"NAICList":["339913"]},"CaseID":"P-2621"}}';
        //Frame Response
        P2EwOnyxConversionResponse OnyxResp = null;
        if(httpRespBody!=null){
            system.debug('--=httpRespBody'+httpRespBody);
                try{
                    OnyxResp = P2EwOnyxConversionResponse.parse(httpRespBody);
                   }
                   catch(JSONException e){
                    if(!isbatch){
                      //  P2EhHelperClass.returnError('Error Parsing the Response received. Bad Response received for EligibilityQQ Call', '', 'Error');
                    }else{
                        System.debug('Error Parsing the Response received. Bad Response received for EligibilityQQ Call' + 'Error');                     
                    }
                }catch(Exception e){
                    if(!isbatch){
                       // P2EhHelperClass.returnError('Exception while processing the response', '', 'Error');
                    }else{
                        System.debug('Exception while processing the response' + 'Error');                                         
                    }    
                }
                
                }system.debug('--=OnyxResp');
                return OnyxResp;        
    }   
  
}