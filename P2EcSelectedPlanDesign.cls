/**
 * @description Controller for Quote Tool
 * 
 * @author P2E Team
 *
 * @change Hitender 10302015 Added the below OR condition to update the decision status of Original plan to 'Not-Sold' when changed plan is sold
 * @change Rajesh 10302015 Added the below condition p.decision == 'Not - Sold' - this condition check re-rate button
 * @change Jaleel 10122017 Added logic for Rich Text Area requirement
 * @change Geetha 12052017 Added logic for Re-Implementation
 */

public class P2EcSelectedPlanDesign extends P2EaWizCacheProcess{  
    public Integer pageId { get; set; }
    public Integer pageToId { get; set; }
    public String pageToUrl { get; set; } 
    public Boolean segre    { get; set; }
    public Boolean disableRegretNote { get; set; }
    public Boolean ShowRegretNote {get ;set;}
    public List<SelectOption> segmentNameList { get; set; }
    public String sv { get; set; }
    //public List<P2EwWizPlanDesign> oldplans;
    public String selectedSegment { get; set; }
    public List<SelectOption> availableProducts { get; set; }
    public List<SelectOption> selectedProducts { get; set; }
    //public List<P2EwWizRateSheets> reqList { get; set; }
    public WizardCache__c wizardCache; 
    public String selectedSoldProduct{get;set;}
    public list<product2> productList{get;set;}
    public String PegaIFrameURL { get; set; }  
    public String ButtonValue{ get; set; }  
    public Boolean ButtonType{get; set;}
    private Map<String, P2EwProductOfferedResponse.POProducts> offeredProdMap;
    public boolean isallexisting {get;set;}
    public P2EwWizCache tempCache;
    public String selPlanId { get; set; }
    public list<P2EcSelectedPlanDesign.ProdSegmentWrp> SelectedsegId{ get; set; }
    public string segsids { get; set; }
    public string pro{ get; set; }
    public string subName{ get; set; }
    //public Map<String, String> planTypeGroupMap; 
    public Note note{get;set;}
    
    /****@Jaleel - 10122017 - RichTextArea Requirement****/
    //public List<Note> noteToDisplay{get;set;}
    public List<Implementation_Notes__c> noteToDisplay{get;set;}
    public List<Implementation_Notes__c> salesNoteToDisplay{get;set;}//added for UWNotes
    public List<Implementation_Notes__c> uwNoteToDisplay{get;set;}//added for UWNotes
    private Id salesNoteRecordTypeId;
    private Id uwNoteRecordTypeId;//added for UWNotes
    public List<String> prdBenLst{get;set;}//Geetha PC-15498
    public List<Product2> prdLst;//Geetha PC-15498
    public Map<String,List<String>> ProdBPMap{get;set;} //Geetha PC-15498
    public Map<String,String> ProdBPNameMap{get;set;} //Geetha PC-15498
    public Integer rowNum{get;set;}
    public product2 proidpla{get;set;}
    public String salesNotes { get; set; }
    public String oliRFPid{ get; set; }
    public String oliPImplStatus{ get; set; }
    public Boolean displayPopup { get; set; }   // Added by Murali for PC-15498 on 9/28/17
    Boolean isSalesNoteAdded=false;
    
    //Added by Murali for Term&Transfer
    public Case ttcase { get; set; }   
    public List<Case> ttcases { get; set; }   
    public boolean isTTEnabled { get; set;} 
    public String ttcaseId { get; set; }
    public String quoteId { get; set; }
    //Till Here
    public String OppId { get; set; }
    public boolean TTonLoad { get; set; }
    
    public String rowIndex{
        get;
        set{
            rowIndex = value;
            system.debug(rowIndex +'rowIndex ');
        }
    }
    public String selPlanIdN{/*Geetha 15498*/
        get;
        set{
            selPlanIdN= value;
            system.debug(selPlanIdN+'selPlanIdN');
        }
    }/*Geetha 15498*/
    public Id selProdId{
        get;
        set{
            selProdId= value;
            system.debug(selProdId +'selProdId');
        }
    }
    
    public String selTTGroup{/*Added for Term&Transfer*/
        get;
        set{
            selTTGroup = value;
            system.debug(selTTGroup+'selTTGroup');
        }
    }/*Added for Term&Transfer*/ 
    public Opportunity oppt{get;set;}
        
    public boolean enableSegmentSection {
        get{
           enableSegmentSection = true;
           if(cache != null){
               if(cache.allPlansMap.isEmpty()){
                   enableSegmentSection = false;
               }
               for(P2EwPlanDesignLite p : cache.allPlansMap.values()){
                   if(p.status != 'Completed'){
                       enableSegmentSection = false;
                       break;
                   }
                }
            }    
            return enableSegmentSection;
        }
        set;
    }
    
     public List<SelectOption> getValue(){
         List<SelectOption> option = new List<SelectOption>();
         option.add(new selectoption('Sold','Sold'));
         option.add(new selectoption('Not - Sold','Not - Sold'));
         option.add(new selectoption('Decision Pending','Decision Pending'));
         option.add(new selectoption('Not Released By Sales','Not Released By Sales')); //PC-11574
         return option;
    }
    
    public List<ProdSegmentWrp> prodSegCloneList{get;set;} //geetha
         
    public List<ProdSegmentWrp> prodSegments {
        get {
            if(prodSegments == null){
                prodSegments = new List<ProdSegmentWrp>();
                if(cache != null){
                    if(cache.prodSegments!=null && !cache.prodSegments.isEmpty()){
                        Set<Id> segIds = new Set<Id>();
                        Set<id> prodIds = cache.prodSegments.keyset();
                        for(Id prodId : cache.prodSegments.keyset()){
                            segIds.addAll(cache.prodSegments.get(prodId));
                        }
                        List<Product2> prodList = Database.Query(P2EhUtility.getQuery('Product2') + ' where id in: prodIds');
                        List<Segmentation__c> segList = Database.Query(P2EhUtility.getQuery('Segmentation__c') + ' where id in: segIds limit 999');
                        for(Product2 prod : prodList) {
                            for(Segmentation__c seg : segList){
                                 if(cache.prodSegments.get(prod.Id).contains(seg.Id) && prod.PlanID__c!=null){
                                    prodSegments.add(new ProdSegmentWrp(prod, seg));
                                }
                            }
                        }
                    }
                }
            }
            return prodSegments;
        }
        set;
    }
    public boolean enableRFP { get; set; }
    public Segmentation__c segment { get; set; }
    public Map<String, Segmentation__c> nameSegmentMap { get; set; }
    public Map<Id, string> mapRecordType = new Map<Id,string>(); 
    
    public Boolean enableWithdraw { get; set; }
    public integer offsetVal { get; set; }//geetha
    public integer limitvar { get; set; }//geetha
    public integer limitval { get; set; }//geetha
    public integer proSegListSize{get;set;}//geetha
    public Quote qt{get;set;}//geetha
    public P2EcSelectedPlanDesign(){
        pageId = 2;
        offSetVal = 0; //geetha                       
        limitvar=10;//geetha
        init();
        for(RecordType rt: [Select Id, Name From RecordType]){
            mapRecordType.put(rt.Id,rt.Name);
        }
        
        //system.debug('Navi Map***'+cache.quickNaviMap);
        //system.debug('Plan Ids***'+cache.allPlansMap);
    }  
    
    public pagereference prev(){
        return null;
    }
    public pagereference save(){
        return null;
    }
    public pagereference next(){
        return null;
    }
    
    private void init(){
        
        
        displayPopup = false;   // Added by Murali for PC-15498 on 9/28/17
        Integer noOfQuotes = 0;
        
        qId = ApexPages.currentPage().getParameters().get('qid');
        ttcaseId = ApexPages.currentPage().getParameters().get('ttcaseId');
        try{
            loadCache();
        }catch(P2EException e){
            e.addSource('P2EcSelectedPlanDesign - init');
        }

        /****@Jaleel - 10122017 - RichTextArea Requirement****/
        salesNoteRecordTypeId = Schema.SObjectType.Implementation_Notes__c.getRecordTypeInfosByName().get('Sales').getRecordTypeId();
        uwNoteRecordTypeId = Schema.SObjectType.Implementation_Notes__c.getRecordTypeInfosByName().get('UW Notes').getRecordTypeId();//added for UWNotes
        //system.debug('cache.createdQuote.RFP_Case_Status__c'+cache.createdQuote.RFP_Case_Status__c);
        //system.debug('cache.selectedOpportunity.StageName'+cache.selectedOpportunity.StageName);
        // Modified by   : JAGAN
        // Modified Date : 22-MARCH-2016
        // HEAT TICKET  : 1727503
        if(cache == null){ 
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Info,'This is not a valid quote');
            ApexPages.addMessage(myMsg);
            System.debug('Inside redirect method');  
            System.debug('msg**' + myMsg);
        }
        // Modified by   : JAGAN
        // Modified Date : 22-MARCH-2016
        // HEAT TICKET  : 1727503 
        else{
        cache.quickNaviMap.get(pageId).isCurrentScreen = true;
        cache.quickNaviMap.get(pageId).isLinkActive = false;
        
        cache.isRFPEnabled = true;
        cache.selProdId = null;
        cache.selectedProduct = null;
        isallexisting = false;
        selectedProducts = new List<SelectOption>();        
        note = new Note();
        ttcase = new Case(); // Added for Term&Transfer
        ttcases =new List<Case>();   //Added for Term&Transfer
        /****@Jaleel - 10122017 - RichTextArea Requirement****/
        //noteToDisplay = new List<Note>();
        salesNoteToDisplay=new List<Implementation_Notes__c>();//UWNotes
        uwNoteToDisplay=new List<Implementation_Notes__c>();//UWNotes
        if(cache.createdQuote.Type__c == 'Inactive'){
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Info,'The quote is inactive and you cannot do any changes');
            ApexPages.addMessage(myMsg);
        }
        //display Notes on UI
        //noteToDisplay = [select id,body,ParentId,title,createdById,createdDate,CreatedBy.name from note where ParentId =:cache.createdquote.Id order by createdDate desc];
        noteToDisplay = new List<Implementation_Notes__c>([Select Id, CreatedDate, CreatedBy.Name, Implementation_Notes__c,Title__c,UW_Notes__c,UW_Notes_UserName__c,UW_Notes_Created_Date__c from Implementation_Notes__c where Quote__c=:cache.createdQuote.Id and (RecordTypeId =:salesNoteRecordTypeId or RecordTypeId =:uwNoteRecordTypeId) order by createdDate desc]);//query modified for UWNotes
        for(Implementation_Notes__c Notes:noteToDisplay){//UWNotes Start
            if(Notes.Implementation_Notes__c!=null && Notes.RecordTypeId==salesNoteRecordTypeId){
                salesNoteToDisplay.add(Notes);
            }
            if(Notes.UW_Notes__c!=null && Notes.Title__c=='UW Notes' && Notes.RecordTypeId==uwNoteRecordTypeId){
                uwNoteToDisplay.add(Notes);
            }  
        }//UWNotes End    
        /****@Jaleel - 10122017 - End of RichTextArea Requirement****/

        //system.debug('notes'+noteToDisplay);
        // if all Existing
        Integer productCount;
        Integer existingCount = 0;
         oppt = new Opportunity();
        if(qId != null){
            qt = [select id,name,Date_Requested_by_AE__c,Claims_Experience_Received__c,UW_Due_Date__c,UW_Due_Date_Reason__c,status,OpportunityId,OwnerId from quote where id =: qId];
          //  qt = [select id,name,status,OpportunityId from quote where id =: qId];
            OppId = qt.OpportunityId; //Added for Term&Transfer
            quoteId = qt.Id; //Added for Term&Transfer
            oppt = [select id,name,Type,StageName,Workflow_Stage__c,Sales_Notes_for_Implementation__c,Strategic_Info_Required__c,Priority_1__c,Priority_2__c,Priority_3__c,Priority_4__c,Priority_5__c,Strategic_Pricing_Recommendations__c from opportunity where id =: qt.OpportunityId];//QA WF
            system.debug('qt.status'+qt.status);
            if(cache.selectedopportunity.name!=oppt.name){
                cache.selectedopportunity.name = oppt.name;  
                cache.selectedOpportunity.StageName = oppt.StageName; 
                cache.selectedOpportunity.Workflow_Stage__c = oppt.Workflow_Stage__c;    // Changed for Sales Stage - Sujit            
                noOfQuotes =  [select count() from quote where opportunityId =: qt.OpportunityId];
                cache.createdQuote.name = 'Q' + cache.selectedOpportunity.name + noOfQuotes;
                
            }
        }
        if(cache.selectedopportunity.type =='Change' || cache.selectedopportunity.type =='Renewal'){
            productCount = cache.allPlansMap.size();
            for(P2EwPlanDesignLite p : cache.allPlansMap.values()){
                if(p.Action == 'Existing'){ 
                    existingCount += 1;  
                    
                }
            }
            if(productCount == existingCount){
                isallexisting  = true;
            }
        }

        disableRegretNote = false;
        isTTEnabled = true;      //Added for Term&Trasfer
        TTonLoad = false;        //Added for Term&Trasfer
        ShowRegretNote = false;
        Integer soldCount = 0;
        Boolean isDecided = false;
        Integer i=0;   
        for(P2EwPlanDesignLite p : cache.allPlansMap.values()){
            if(p.isNegotiated==null){
                 p.isNegotiated=false;
            }
            if(p.decision == 'Sold'){
                 soldCount = soldCount + 1;
            }
            if(p.decision != 'Decision Pending' && !isDecided){
                isDecided = true;
            }
            if(p.decision == 'Not Released By Sales'){
                System.debug('Not Released By Sales**');
                ShowRegretNote = true;
            }
        }
        if(soldCount == cache.allPlansMap.size()){
            disableRegretNote = true;
        }
        
        cache.quickNaviMap.get(pageId).isCurrentScreen = true;      
        cache.quickNaviMap.get(pageId).isLinkActive = false;
         
        if(cache.createdQuote.RFP_Case_Id__c != null){
            cache.isRFPEnabled = False;
        }
        system.debug('cache.isRFPEnabled line 202'+cache.isRFPEnabled);
        system.debug('cache.isRFPEnabled line 203'+cache.createdQuote.Type__c );
        if(cache.createdQuote.Type__c == 'Inactive'){
            cache.isRFPEnabled = False;
        }
        system.debug('cache.allPlansMap line 205'+cache.allPlansMap);
        if(cache.allPlansMap.isEmpty()){
            cache.isRFPEnabled = False;
        }
        for(P2EwPlanDesignLite p : cache.allPlansMap.values()){
            system.debug('$$$$'+p);
            if(p.status != 'Completed'){
                cache.isRFPEnabled = false;
                break;
            }
        }
        if(cache.createdQuote.RFP_Case_Id__c != null){
            Pega__c callDetails = new Pega__c();
            callDetails = Pega__c.getInstance('PegaExtender');
            PegaIFrameURL = String.valueOf(callDetails.endPointURL__c)+'&CaseID='+cache.createdQuote.RFP_Case_Id__c;
        }
        List<OpportunityLineItem> oliList1 = [Select Id, Action__c, IsRerate__c,Decision_Status__c, Product2Id,Parent_Impl_Case_Id__c, RFP_Case_Id__c, Parent_Impl_Case_Status__c, Group_Number__c, product2.PlanId__c From OpportunityLineItem 
                            Where OpportunityId =: cache.selectedOpportunity.Id AND RFP_Case_Id__c =: cache.createdQuote.RFP_Case_Id__c 
                            AND ((Decision_Status__c = 'Sold' AND Action__c IN ('New','Update','Existing')) OR (Decision_Status__c = 'Not - Sold' AND Action__c ='Discontinue'))]; 
        
        if((cache.createdQuote.RFP_Case_Status__c ==null && cache.createdQuote.RFP_Case_Id__c == null) || cache.createdQuote.RFP_Case_Status__c == 'Resolved-Withdrawn'){ // Modified for PC-12024
            ButtonType=false; // disable
            ButtonValue = 'Negotiation';
        }
        if(cache.createdQuote.RFP_Case_Status__c != null && cache.createdQuote.RFP_Case_Id__c != null){
            ButtonType=true; //enable
            if(cache.createdQuote.RFP_Case_Status__c =='Pending-Review'){
                ButtonValue='Negotiation';
                //ButtonType=True;
            }else if(cache.createdQuote.RFP_Case_Status__c =='Resolved-Completed' || cache.createdQuote.RFP_Case_Status__c =='Completed'){
                ButtonValue='Re-Rate';
                //ButtonType=true; // enable
            }
        }
        
        // Toggle Negotiate Button
        Integer reRateProductCount; 
        Integer soldProductCount =0;
        
        
        for(OpportunityLineItem oli1 : olilist1){
            oliRFPid = oli1.RFP_Case_Id__c;
            oliPImplStatus = oli1.Parent_Impl_Case_Status__c;
            //Putting the group number into cache for implemented new plans
            if(oli1.product2 != null && cache.allPlansMap.get(oli1.product2.planId__c) != null){
                cache.allPlansMap.get(oli1.product2.planId__c).GroupNumber = oli1.Group_Number__C;
            }
            system.debug('line 270'+olilist1);
            system.debug('line 271'+oli1.Parent_Impl_Case_Id__c);
            system.debug('line 272'+oli1.Decision_Status__c);
            system.debug('line 273'+cache.parentimplCaseId);
            
             //Added for Term and Transfer- START
            if(oli1.Parent_Impl_Case_Id__c!=null && oli1.IsRerate__c == false && (oli1.Parent_Impl_Case_Status__c=='Pending-Review'||oli1.Parent_Impl_Case_Status__c=='Resolved-Completed')){
                isTTEnabled = false;
            }// Term&Transfer END
            
            
            if(ButtonValue =='Re-Rate'){
                //Disable - Removing all below conditions
                // 1. Any One Plan is SOLD/NOT-SOLD - oli1.Decision_Status__c
                // 2. If new Plan, oli1.Parent_Impl_Case_Id__c == null --> Normal Re-Rate also
                // 3. If Existing, oli1.Parent_Impl_Case_Id__c != null && cache.parentimplCaseId != null ---> only for Re-IMPL's Re-Rate
                // 4. ALL Plans are 'Resolved Completed' 
                if(oliPImplStatus =='Resolved-Completed'){
                    i++;
                }
                system.debug('line 288'+i);
                /*
                if((oli1.Parent_Impl_Case_Id__c == null 
                        && oli1.Decision_Status__c!='Decision Pending') 
                    || (oli1.Parent_Impl_Case_Id__c != null 
                        && cache.parentimplCaseId != null 
                        && oli1.Decision_Status__c!='Decision Pending' && oli1.IsRerate__c == true) 
                    ){
                    ButtonType = false;
                }
                */
            }
        }
        system.debug('line 297'+i);
        system.debug('line 299'+olilist1.size());
        system.debug('line 300'+ButtonType);
        if(i == olilist1.size() && ButtonType && i > 0){
            ButtonType = false;
        }
        
        //Disable
        // 1. Any One Plan is SOLD/NOT-SOLD
        /*if(ButtonValue =='Re-Rate'){
            for(P2EwPlanDesignLite pdl : cache.allPlansMap.values()){
                if(pdl.action != 'Decision Pending' && ){
                    ButtonType = false;
                }
            }
        }*/
        
        //auto populate Date requested by AE
        Boolean flag = true;
        Date d = Date.today();
        for(P2EwPlanDesignLite p : cache.allPlansMap.Values()){
            system.debug(p.decision+'Line 217');
            if(p.status != 'Completed'){
                flag = false;
            }
        }
        
        if(flag && cache.createdQuote.RFP_Case_Id__c == null){
            if(cache.wizardType != 'Re-Rate'){
                if((Cache.selectedAccount.NumberOfEmployees <= 1000) && (!cache.createdQuote.ReqClaimsExperience__c && !cache.createdQuote.ReqCostSavingPG__c && !cache.createdQuote.ReqDeviationReview__c && !cache.createdQuote.ReqDisruptionAnalysisReport__c && !cache.createdQuote.ReqFeeAnalysis__c && !cache.createdQuote.ReqGeoAccessReport__c && !cache.createdQuote.ReqNetworkDiscount__c && !cache.createdQuote.ReqQuestionnaire__c && !cache.createdQuote.ReqRecruitmentPG__c && !cache.createdQuote.ReqRepricing__c && !cache.createdQuote.DHMO_Plan_Comparsion__c && !cache.createdQuote.ReqPG__c && !cache.createdQuote.Req_Provider_Utilization__c && !cache.createdQuote.Req_Network_Discounts__c && !cache.createdQuote.Req_Provider_Counts_NW_Comp__c && !cache.createdQuote.Req_Network_Growth_and_Turnover__c && !cache.createdQuote.Req_Adhoc_Provider_Report__c && !cache.createdQuote.Req_Financial_Experience__c && !cache.createdQuote.Req_Network_Utilization__c && !cache.createdQuote.Req_Maximum_Report__c && !cache.createdQuote.Req_Executive_Summary__c && !cache.createdQuote.Req_DHMO_Financial__c && !cache.createdQuote.Req_DHMO_Utilization__c && !cache.createdQuote.Req_Actuarial_Adhoc_Report__c && !cache.createdQuote.Req_Form_5500__c)){
                    cache.createdQuote.Date_Requested_by_AE__c = d.addDays(5);
                    system.debug('Date**'+ cache.createdQuote.Date_Requested_by_AE__c);
                }else if(cache.createdQuote.ReqClaimsExperience__c || cache.createdQuote.ReqCostSavingPG__c || cache.createdQuote.ReqDeviationReview__c|| cache.createdQuote.ReqDisruptionAnalysisReport__c || cache.createdQuote.ReqFeeAnalysis__c || cache.createdQuote.ReqGeoAccessReport__c || cache.createdQuote.ReqNetworkDiscount__c || cache.createdQuote.ReqQuestionnaire__c || cache.createdQuote.ReqRecruitmentPG__c || cache.createdQuote.ReqRepricing__c || cache.createdQuote.DHMO_Plan_Comparsion__c || cache.createdQuote.ReqPG__c || cache.createdQuote.Req_Provider_Utilization__c || cache.createdQuote.Req_Network_Discounts__c || cache.createdQuote.Req_Provider_Counts_NW_Comp__c || cache.createdQuote.Req_Network_Growth_and_Turnover__c || cache.createdQuote.Req_Adhoc_Provider_Report__c || cache.createdQuote.Req_Financial_Experience__c || cache.createdQuote.Req_Network_Utilization__c || cache.createdQuote.Req_Maximum_Report__c || cache.createdQuote.Req_Executive_Summary__c || cache.createdQuote.Req_DHMO_Financial__c || cache.createdQuote.Req_DHMO_Utilization__c || cache.createdQuote.Req_Actuarial_Adhoc_Report__c || cache.createdQuote.Req_Form_5500__c){
                    cache.createdQuote.Date_Requested_by_AE__c = d.addDays(10);
                    system.debug('Date**'+ cache.createdQuote.Date_Requested_by_AE__c);
                }else{
                   cache.createdQuote.Date_Requested_by_AE__c = d.addDays(10);
                }
            }
            if(cache.wizardType == 'Re-Rate'){
                cache.createdQuote.Date_Requested_by_AE__c = d.addDays(3);
            }
        }
        loadSegments();
        
        //Enabling/Disabling Withdraw Button
        //Modified the code for PC-12024
        enableWithdraw = false;
        
         //Added for Term&Transfer - START
          if(cache.createdQuote.RFP_Case_Status__c == 'Resolved-Withdrawn' || oppt.StageName == Label.Sales_Stages_Closed_Change_Implemented ||oppt.Workflow_Stage__c == Label.Sales_Stages_Closed_Change_Implemented || oppt.Workflow_Stage__c ==Label.Sales_Stages_Closed_After_MTV_Implementations || (qt!=null && qt.Status=='Withdrawn')){
              isTTEnabled = false;
          }//End
          
        // Changed for Sales Stage - Sujit        
        if(cache.createdQuote.RFP_Case_Status__c == 'Resolved-Withdrawn' || oppt.StageName == Label.Sales_Stages_Closed_Change_Implemented || cache.selectedOpportunity.StageName == Label.Sales_Stages_Closed_Change_Implemented || cache.selectedOpportunity.Workflow_Stage__c == Label.Sales_Stages_Closed_After_MTV_Implementations){
            enableWithdraw = false;
        }else{
            enableWithdraw = true;
        }
        //Upto this modified for PC-12024
        // Changed for Sales Stage - Sujit
        system.debug('cache.selectedOpportunity.stageName'+cache.selectedOpportunity.stageName);
        system.debug('cache.selectedOpportunity.Workflow_Stage__c'+cache.selectedOpportunity.Workflow_Stage__c);
        
         if((cache.selectedOpportunity!=null && ((cache.selectedOpportunity.stageName == Label.Sales_Stages_Closed_Withdrawn)
        ||(cache.selectedOpportunity.stageName == Label.Sales_Stages_Closed)
        ||(cache.selectedOpportunity.stageName == Label.Sales_Stages_Declined_To_Quote_DTQ)))
        ||(qt!=null && qt.Status=='Withdrawn')){
            cache.isRFPEnabled = false;
            ButtonType = false;
            enableWithdraw = false;
            //cache.quickNaviMap.get(1).isLinkActive = false;
            for(P2EwWizQuickNavi WQN : cache.quickNaviMap.values()){
                WQN.isLinkActive = false;
                WQN.isCurrentScreen = false;
            }
        }
        
        
        //Commented below snippet for PC-12024
        /*if(isDecided && enableWithdraw){
            enableWithdraw = false;
        }*/
        firstSet(limitvar);//geetha
        //NEWLY ADDED - PC-11713
        /*integer indays;
        if(cache.selectedOpportunity.Contract_End_Date__c !=NULL){
            System.debug(System.Today() +'...'+ cache.selectedOpportunity.Contract_End_Date__c);
            indays = integer.valueof(System.today().daysBetween(cache.selectedOpportunity.Contract_End_Date__c));
            System.debug('In days**' + indays);
            if(indays <= 15 && cache.selectedOpportunity.StageName != 'Retention Activity'){
                ButtonType = false;
            }
        }*/
        List<String> BenIds;//Geetha PC-15498 Start
        ProdBPMap=new Map<String,List<String>>();
        ProdBPNameMap=new Map<String,String>();
        prdLst=[select id,GroupPlanName__c,PlanID__c,(SELECT ID,Name,Benefit_Package__c,Benefit_Package_ID__c,Product__c FROM ProdBenefits__r) from product2 where PlanID__c in: cache.allPlanIds];
        for(product2 prd:prdLst){
           if(!ProdBPNameMap.containsKey(prd.PlanID__c) && prd.GroupPlanName__c!=null){
              ProdBPNameMap.put(prd.PlanID__c,prd.GroupPlanName__c);
           }
           else if(!ProdBPNameMap.containsKey(prd.PlanID__c) && prd.GroupPlanName__c==null)
           {
                ProdBPNameMap.put(prd.PlanID__c,'');
           }
           if(!prd.ProdBenefits__r.isEmpty()){
                BenIds = new List<String>();
                for(ProdBenefit__c PB:prd.ProdBenefits__r){
                    BenIds.add(PB.Benefit_Package_ID__c);
                }  
                ProdBPMap.put(prd.PlanID__c,BenIds);  
            }
            else{
                ProdBPMap.put(prd.PlanID__c,new List<String>());
            }
         }//Geetha PC-15498 End
         
         //Added for 2-way communication
         if(cache.isRFPEnabled || cache.createdQuote.Claims_Experience_Received__c || qt.Claims_Experience_Received__c){  
             cache.createdQuote.Claims_Experience_Received__c = true;
         }
         
         if(cache.isRFPEnabled || cache.selectedOpportunity.Strategic_Info_Required__c){  
             oppt.Strategic_Info_Required__c = true;
         }
         //Till here
         
         //Added for Term&Transfer - START
          String ttcaseQuery =P2EhUtility.getQuery('Case');
          String frameWhereClause = ' where Related_Opportunity__c ='+'\''+ OppId +'\' AND Term_And_Transfer__c = true AND (Type = \'Term and Transfer\' AND Quote__c = '+'\''+ quoteId+'\') AND Term_Transfer_Type__c !=NULL AND (Recordtype.Name = \'Term And Transfer Group\' OR Recordtype.Name = \'Term And Transfer Division\')'; 
          
          if(ttcaseId!=null && ttcaseId!=''){
               ttcaseQuery += ' where Id ='+'\''+ ttcaseId+'\' AND Related_Opportunity__c ='+'\''+ OppId +'\'';   
          }else if(oppt.Type=='New'){
              ttcaseQuery += frameWhereClause;
          }else if(oppt.Type=='Renewal'){
              ttcaseQuery += frameWhereClause+' AND Change_Type__c = NULL AND Change_SubType__c = NULL AND Group__c!=NULL';   
          }else if(oppt.Type=='Change'){
              ttcaseQuery += frameWhereClause+' AND (Change_Type__c = NULL OR Change_Type__c = \'Rate Impacting Changes\') AND Group__c!=NULL';  
          }
          ttcases = database.query(ttcaseQuery);
          System.debug('ttcases' + ttcases); 
            
          if(ttcases.size()>0){
              ttcase = ttcases[0];
              ttcaseId = ttcases[0].Id;
              TTonLoad = ttcase.Term_And_Transfer__c;
          }
          // Term&Transfer - END
      
      }//Cache not null else End
      
    }// Init method End
    
    //Added for Term&Transfer - START
    public void enableEnrollmentVariation(){
        System.debug('Term and Transfer checkbox###' + ttcase.Term_And_Transfer__c);
        System.debug('Enrollment Variation checkbox###' + ttcase.Enrollment_Variation__c);
        System.debug('ttcases###' + ttcases);
        if(ttcases.size()>0){
            for(Case ttc:ttcases){
                ttc.Enrollment_Variation__c = ttcase.Enrollment_Variation__c;
            }
             update ttcases;
        }
        System.debug('ttcase.Enrollment_Variation__c###' + ttcase.Enrollment_Variation__c);
    }
    // Term&Transfer - END
    
    public void firstSet(Integer limitVal){//geetha       
        offsetVal = 0;
        this.limitval = limitval; 
        proSegListSize = prodsegments.size();                     
        for(ProdSegmentWrp psw: prodsegments){                                    
            prodSegCloneList= new List<ProdSegmentWrp>();        
            if(prodsegments.size() >= limitval){ 
                for(integer i=offsetval;i<limitval;i++){            
                    prodSegCloneList.add(prodsegments.get(i));            
                }
            }else{
                for(integer i=offsetval; i<=prodsegments.size()-1;i++){
                    prodSegCloneList.add(prodsegments.get(i));
                }   
            }
        }
    }
    
    public PageReference getNextSet() {
        
        offsetVal += limitvar;
        limitval += limitvar;                
        prodSegCloneList.clear();        
        if(prodsegments.size() < limitval){            
            for(integer i=offsetval;i<=prodsegments.size()-1;i++)
            {
                prodSegCloneList.add(prodsegments.get(i));
                
            }
            
        }else{
            for(integer i = offsetVal; i < limitVal; i++){
                
                    prodSegCloneList.add(prodsegments.get(i));
                
            }
        }
        
        return null;
    }

    //Reterive the previous set of records
    public PageReference getPreviousSet() {
        offsetVal -= limitvar;
        limitval -= limitvar;
        prodSegCloneList.clear();       
        for(integer i=offsetval;i<limitval;i++)
            {
                prodSegCloneList.add(prodsegments.get(i));                
            }               
        return null;
    }//geetha
    
    public PageReference soldProd(){
        String selProdId = Apexpages.currentPage().getParameters().get('prod');
        String newDecision = Apexpages.currentPage().getParameters().get('dec');
        String selPlanId;
        String clonedPlanId;
        Set<String> toNotSold;
        Map<Id, String> prodPlanIdMap = new Map<Id, String>();
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            if(selProdId == wpd.ProductId){
                selPlanId = wpd.PlanId;
                clonedPlanId = wpd.ClonedPlanId;
                prodPlanIdMap.put(Id.valueOf(selProdId), selPlanId);
            }
        }
        if(cache.selectedOpportunity.type == 'Renewal' || cache.selectedOpportunity.type == 'Change'){
            for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
                /* Added the below OR condition to update the decision status of Original plan to 'Not-Sold' 
                when changed plan is sold- Hitendar
                */
                if((wpd.ClonedPlanId == selPlanId || wpd.PlanId == clonedPlanId) && newDecision=='Sold'){
                    if(toNotSold==null){
                        toNotSold = new Set<String>();
                    }
                    toNotSold.add(wpd.PlanId);
                    prodPlanIdMap.put(wpd.ProductId, wpd.PlanId);
                }
            }
            if(toNotSold!=null && !toNotSold.isEmpty()){
                for(String planId : toNotSold){
                    if(cache.allPlansMap.get(planId).decision != 'Sold'){
                        cache.allPlansMap.get(planId).decision = 'Not - Sold';
                        if(cache.allPlansMap.get(planId).action == 'Existing'){
                            cache.allPlansMap.get(planId).action = 'Discontinue';
                        }
                    }
                }
            }
        }
        Boolean changeQuoteStatus = true;
        Boolean changeOpp = false;
        system.debug('1111111'+cache.allPlansMap.values());    
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            system.debug('selProdId'+selProdId); 
            system.debug('wpd.ProductId'+wpd.ProductId);
            if(selProdId == wpd.ProductId){
                if(wpd.action == 'Discontinue' && wpd.decision == 'Sold'){
                    wpd.action = 'Existing';
                    wpd.freezed = false;
                }
                if(wpd.action == 'Existing' && wpd.decision == 'Not - Sold'){
                    wpd.action = 'Discontinue';
                }
                if(wpd.decision == 'Sold'){
                    if(cache.selectedopportunity.type == 'Renewal') {                       
                        //cache.selectedopportunity.stagename = 'Renewal Decision Won';
                        cache.selectedopportunity.stagename = Label.Sales_Stages_Won; // Changed for Sales Stage - Sujit
                        cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Renewal_Decision_Won; // Changed for Sales Stage - Sujit
                        
                    }else{
                        //cache.selectedopportunity.StageName = 'Decision won';
                        cache.selectedopportunity.stagename = Label.Sales_Stages_Won; // Changed for Sales Stage - Sujit
                        cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Decision_won; // Changed for Sales Stage - Sujit
                    }  
                    system.debug('@@@@@@'+cache.selectedopportunity.StageName);  
                    system.debug('@@@@@@'+cache.selectedopportunity.Workflow_Stage__c);                 
                    //cache.selectedopportunity.Reason_Won_Lost__c= 'Price';                  
                    //cache.selectedopportunity.ForecastCategoryName = 'Commit';                  
                    //cache.selectedopportunity.Probability = 90;
                    cache.selectedopportunity.ForecastCategoryName = Label.ForecastCategoryName_Closed;                  
                    cache.selectedopportunity.Probability = Integer.valueOf(Label.Opportunity_Probability_Closed);
                    changeOpp = true;
                }
            }
            if(wpd.decision == 'Decision Pending'){
                changeQuoteStatus = false;
            }
        }
        system.debug('******'+changeOpp);
        if(changeOpp){
            update cache.selectedOpportunity;   
        } 
     
        List<OpportunityLineItem> oliList = [Select Id, Action__c, Decision_Status__c, Product2Id, RFP_Case_Id__c, Group_Number__c From OpportunityLineItem 
                            Where Product2Id IN: prodPlanIdMap.keyset() and OpportunityId =: cache.selectedOpportunity.Id];
        if(!oliList.isEmpty()){
            for(OpportunityLineItem oli : oliList){
                oli.Decision_Status__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).decision;
                oli.Action__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).action;
                oli.Group_Number__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).groupNumber;
                oli.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                //oli.IsRerate__c = true; // Added by parthi - need to check to put or not.
                if(oli.Parent_Impl_Case_Id__c!=null && cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).decision == 'Not - Sold'){
                    oli.Parent_Impl_Case_Id__c = null;
                }
            }
            update oliList;
                        
        }
        cache.selProdId = null;
        cache.selectedProduct = null;
        saveCache();
        //updateOpportunityValue();
             
        if(changeQuoteStatus){
            cache.createdQuote.Status = 'Completed';
            update cache.createdQuote;
        }
        PageReference spd = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
        spd.setRedirect(true);
        return spd;
    }
    
    // Method to update opportunity value for the sold product
    /*
    private void updateOpportunityValue(){
    
        List<Id> listProd = new List<Id>();
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            if(wpd.decision == 'Sold'){
                listProd.add(wpd.productId);        
            }    
        }
        list<WPDCache__c> wpdlist = [select Id,product__c, WPDJSON__c from WPDCache__c where product__c in: listProd Order by PartNumber__c ASC];//Added Product__c by Geetha
                system.debug('wpdlist line395'+wpdlist);
        Map<Id,string> mapWpd = new Map<Id,string>();
        for(WPDCache__c wpdCache : wpdlist){
            String temp = '';
            if(mapWpd.get(wpdCache.product__c) != null){
                temp = mapWpd.get(wpdCache.product__c);
            }
            temp += wpdCache.WPDJSON__c;
            mapWpd.put(wpdCache.product__c,temp);
        }
        //Decimal i = 0.0;
        //Decimal j = 0.0;
        for(string wpdJson: mapWpd.values()){
            P2EwWizPlanDesign wpd = (P2EwWizPlanDesign) System.Json.deserialize(wpdJson, P2EwWizPlanDesign.class);
            for(P2EwWizRateSheets rs : wpd.rateSheetList){
                for(Rates__c r : rs.originalRates){
                    if(r.ProposedRate__c!=null && r.TierCensus__c!=null){
                        system.debug('Line 428' + r.ProposedRate__c);
                        system.debug('Line 429' + r.TierCensus__c);
                        if(cache.selectedOpportunity.Amount == null){
                            cache.selectedOpportunity.Amount = 0.0;
                        }
                        cache.selectedOpportunity.Amount = r.TierCensus__c * r.ProposedRate__c;
                        if(wpd.product.Delivery_Method__c == 'Fee For Service'){
                            if(cache.selectedOpportunity.FFS_Proposal_Value__c == null){
                                cache.selectedOpportunity.FFS_Proposal_Value__c = 0.0;
                            }
                            system.debug('Line 438' + r.ProposedRate__c);
                            system.debug('Line 439' + r.TierCensus__c);
                            cache.selectedOpportunity.FFS_Proposal_Value__c = r.TierCensus__c * r.ProposedRate__c;
                        }
                    }
                }
            }
        }
     }
     */
    
    public pagereference soldProduct(){
        Boolean changeQuoteStatus = true;
        Map<Id, Set<ID>> mapNewProdIdOldProdIds = new Map<Id, Set<Id>>();
        Set<Id> setProdIds = new Set<Id>();
        Map<Id, OpportunityLineItem> mapOli = new Map<Id, OpportunityLineItem>();
        List<OpportunityLineItem> listOliToBeUpdated = new List<OpportunityLineItem>();
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            setProdIds.add(wpd.productId);
        }
        for(OpportunityLineItem OLI: [Select Id, Action__c, Decision_Status__c, Product2Id, RFP_Case_Id__c, Group_Number__c From OpportunityLineItem 
                        Where Product2Id IN: setProdIds and OpportunityId =: cache.selectedOpportunity.Id]){
            mapOli.put(OLI.Product2Id, OLI);
        }
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){          
            if(wpd.action == 'Discontinue' && wpd.decision == 'Sold'){
                wpd.action = 'Existing';
            }
            if(wpd.action == 'Existing' && wpd.decision == 'Not - Sold'){
                wpd.action = 'Discontinue';
            }
        }
        if(cache.selectedOpportunity.Type != 'Renewal'){
            for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
                OpportunityLineItem updateOLI = mapOli.get(wpd.ProductId);
                updateOLI.Action__c = wpd.Action;
                updateOLI.Decision_Status__c = wpd.decision;
                updateOLI.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                if(wpd.groupNumber!=null){
                    updateOLI.Group_Number__c = wpd.groupNumber;
                }
                listOliToBeUpdated.add(updateOLI);
            }
        }
        if(cache.selectedOpportunity.Type == 'Renewal'){
            Map<String, Set<String>> mapParentClonedPlanIds = new Map<String, Set<String>>();
            for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
                if(wpd.clonedPlanId != Null && wpd.clonedPlanId != ''){
                    if(!mapParentClonedPlanIds.containsKey(wpd.clonedPlanId)){
                        mapParentClonedPlanIds.put(wpd.clonedPlanId, new Set<String>());
                        mapParentClonedPlanIds.get(wpd.clonedPlanId).add(wpd.clonedPlanId);
                    }
                    mapParentClonedPlanIds.get(wpd.clonedPlanId).add(wpd.PlanId);
                }
            }
            for(String updateParent: mapParentClonedPlanIds.keySet()){
                for(String updateP: mapParentClonedPlanIds.get(updateParent)){
                    if(cache.allPlansMap.get(updateP).decision == 'Sold'){
                        if(cache.allPlansMap.get(updateP).action == 'Discontinue'){
                            cache.allPlansMap.get(updateP).action = 'Existing';
                        } 
                        for(String UpdatePP: mapParentClonedPlanIds.get(updateParent)){
                            for(P2EwPlanDesignLite wpdl: cache.allPlansMap.values()){
                                if(wpdl.PlanId == updatePP){
                                    if(wpdl.PlanId != updateP){
                                        wpdl.decision = 'Not - Sold';
                                    }
                                }
                            }
                        }                       
                    }
                }
            }

            for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
                OpportunityLineItem updateOLI = mapOli.get(wpd.ProductId);
                System.debug('test2_mapOli' +mapOli);
                 System.debug('test2_wpd.ProductId' +wpd.ProductId);
                System.debug('test2_updateOLI' +updateOLI);
                updateOLI.Action__c = wpd.Action;
                updateOLI.Decision_Status__c = wpd.decision;
                updateOLI.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                if(wpd.groupNumber!=null){
                    updateOLI.Group_Number__c = wpd.groupNumber;
                }
                listOliToBeUpdated.add(updateOLI);
            }            
        }
        
        if(listOliToBeUpdated.size() > 0){
            update listOliToBeUpdated;
        }        
        
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            /*productList.add(wpd.product);
        }
        for(Product2 prd: productList){*/
            if(wpd.decision == 'Sold'){
               if(cache.selectedopportunity.type == 'Renewal') {
                    //cache.selectedopportunity.stagename = 'Renewal Decision Won';
                    cache.selectedopportunity.stagename = Label.Sales_Stages_Won;// Changed for Sales Stage - Sujit
                    cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Renewal_Decision_Won;// Changed for Sales Stage - Sujit                    
               }else{
                    //cache.selectedopportunity.StageName = 'Decision won';
                    cache.selectedopportunity.stagename = Label.Sales_Stages_Won;// Changed for Sales Stage - Sujit
                    cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Decision_won;// Changed for Sales Stage - Sujit  
               } 
               system.debug('$$$$$$$'+cache.selectedopportunity.StageName);   
               system.debug('$$$$$$$'+cache.selectedopportunity.Workflow_Stage__c);             
               //cache.selectedopportunity.Reason_Won_Lost__c= 'Price';                  
               //cache.selectedopportunity.ForecastCategoryName = 'Commit';                  
               //cache.selectedopportunity.Probability = 90;
               cache.selectedopportunity.ForecastCategoryName = Label.ForecastCategoryName_Closed;                  
               cache.selectedopportunity.Probability = Integer.valueOf(Label.Opportunity_Probability_Closed);
            }
        }
        update cache.selectedopportunity;
        
        for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
            system.debug('Line 434' + wpd.decision);
            if(wpd.decision == 'Decision Pending'){
                changeQuoteStatus = false;
            }
        }
        if(changeQuoteStatus ){
            system.debug('Line 440 Going to complete the quote');
            cache.createdQuote.Status = 'Completed';
            update cache.createdQuote;
        }        
        cache.selProdId = null;
        cache.selectedProduct = null;
        saveCache();
        PageReference selectedPlanDesignPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
        selectedPlanDesignPage.setRedirect(true);
        return selectedPlanDesignPage;
    }
    
    public pagereference edit(){ //remember to set selProdId from apex:param
        String selProdId = cache.selProdId;
        if(cache.createdQuote.RFP_Case_Status__c == 'Pending-Review'){
            loadCache();
        }
        cache.selProdId = selProdId;
        system.debug('cache.selProdId :: ' + cache.selProdId);
        //system.debug('cache.selectedProduct :: ' + cache.selectedProduct);
        system.debug('cache.allPlansMap :: ' + cache.allPlansMap);
        
        cache.selectedProduct = null;
        cache.quickNaviMap.get(pageId).isLinkActive = true;
        cache.quickNaviMap.get(pageId).isCurrentScreen = false;
        if(ButtonValue =='Re-Rate'){
           for(P2EwPlanDesignLite wpd : cache.allPlansMap.values()){
               wpd.isNegotiated=false;
           } 
        }
        try{
            saveCache();
        }
        catch(P2EException e){
            e.addSource('P2EcSelectedPlanDesign - edit()');
            e.logException();
        }   
        PageReference planDesignPage2 = new PageReference('/apex/P2EvPlanDesignInformation?qId='+qId +'&displayName=N');
        planDesignPage2.setRedirect(true);
        return planDesignPage2;
    }
    
    public PageReference viewRate(){
        cache.quickNaviMap.get(pageId).isLinkActive = true;
        cache.quickNaviMap.get(pageId).isCurrentScreen = false;
          try{
         saveCache();
        }
        catch(P2EException e){
                e.addSource('P2EcSelectedPlanDesign - viewRate()');
                e.logException();
            }  
        PageReference rateInformationPage = new PageReference('/apex/P2EvRateSheets?qId='+qId+'&type='+'Rates');
        rateInformationPage.setRedirect(true);
        return rateInformationPage;
    }
    
    public PageReference remove(){
        system.debug('Line 443'+cache.SelProdId);
        Set<String> changeToExisting = new Set<String>();
        Integer removePlan = 0;
        Integer removeIndex = -1;
        String removePlanId='';
        for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
            if((cache.SelProdId == wpd.ProductId)){
                if((wpd.action == 'New' || wpd.action == 'Update')){
                    removePlanId = wpd.PlanId;
                    system.debug('123'+removePlanId);
                    //Added the below logic
                    if(wpd.action == 'Update'){
                        changeToExisting.add(wpd.origPlanId);
                    }  
                }
                if(wpd.action == 'Existing'){
                    wpd.action = 'Discontinue';
                }
            }
            if(wpd.origProdId == cache.SelProdId){
                    wpd.origProdId = null;
            }
        }
        for(String apId: cache.allPlanIds){
            if(apId == removePlanId){
               removeIndex = removePlan;
            }
            removePlan += 1;
        }
        system.debug(removeIndex + 'Line 527');
        if(removeIndex>-1){            
            OpportunityLineItem OLIToBeDeleted = [Select Id,Product2Id From OpportunityLineItem Where Product2Id=: cache.SelProdId And OpportunityId =: cache.SelectedOpportunity.Id];
            Product2 ProdToBeDeleted = [Select Id From Product2 Where Id=: cache.SelProdId];
            system.debug('####'+ProdToBeDeleted);
            List<CostShare__c> CSToBeDeleted = [Select Id, Plan_Design__c from CostShare__c Where Plan_Design__c=:ProdToBeDeleted.Id];
            List<WPDCache__c> listWPDToBDeleted = [Select Id, Product__c From WPDCache__c Where Product__c=: ProdToBeDeleted.Id];            
            String planKey = cache.allPlanIds[removeIndex];
            cache.allPlanIds.remove(removeIndex);
            cache.allPlansMap.remove(planKey);
              system.debug('%%%%'+removeIndex);
            try{
            delete listWPDToBDeleted;
            delete OLIToBeDeleted;
            delete ProdToBeDeleted;
            delete CSToBeDeleted;
            }catch(Exception e){
                system.debug(e);
            }
        }
        system.debug(cache.SelProdId + 'Line 542');
        system.debug(cache.SelectedOpportunity.Id + 'Line 543');
        //OpportunityLineItem OLIToBeUpdated = [Select Id, Action__c, Product2Id From OpportunityLineItem Where Product2Id=: cache.SelProdId And OpportunityId =: cache.SelectedOpportunity.Id];
        /*
        for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
            if(wpd.ProductId == cache.selProdId){
                //Moving this code above to avoid unnecessary for loop
                
                if(wpd.action == 'Existing'){
                    wpd.action = 'Discontinue';
                }
                
                //Moving below code before removing the selected planId as this code will never be executed if this is here
                
                if(wpd.action == 'Update'){
                    changeToExisting.add(wpd.origPlanId);
                }
                
                
                //Commenting this code as this action is already done by above code
               
                if(wpd.action == 'New' || wpd.action == 'Update'){
                    cache.allPlansMap.remove(wpd.PlanId);
                }
                
            }
        }
        */
        //update OLIToBeUpdated;
        if(!changeToExisting.isEmpty()){
            for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
                if(changeToExisting.contains(wpd.PlanId)){
                    wpd.action = 'Existing';
                    wpd.Freezed = false;
                }
            }
        }
        system.debug(cache.allPlansMap.keySet()+'Line 484'+cache.allPlansMap.Values());
        //saveCache();
        Boolean QuoteStatusCheck = true;
        for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
            system.debug('Line 554' +wpd.decision);
            if(wpd.decision == 'Decision Pending'){
                QuoteStatusCheck = false;
            }
        }
        if(QuoteStatusCheck){
            system.debug('Line 560 Going to complete the quote');
            cache.createdQuote.Status = 'Completed';
            update cache.createdQuote;
        }
        cache.selProdId = null;
        cache.selectedProduct = null;
        cache.frameFullLink();
        saveCache();
        PageReference selectedPlanDesignPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
        selectedPlanDesignPage.setRedirect(true);
        return selectedPlanDesignPage;
    }
    public PageReference pageNavigate(){  
        if(cache.createdQuote.RFP_Case_Status__c == 'Pending-Review'){
            loadCache();
        }      
        cache.quickNaviMap.get(pageId).isLinkActive = true;
        cache.quickNaviMap.get(pageId).isCurrentScreen = false;
        PageReference landingPage;
        if(pageToUrl == 'P2EvSearchPlanDesign'){
            landingPage = new PageReference('/apex/'+ pageToUrl +'?wiz=Y&oppId='+cache.selectedOpportunity.Id);
        }
        else if(pageToUrl == 'P2EvPlanDesignInformation'){
            cache.selProdId = cache.allPlansMap.get(cache.allPlanIds.get(pageToId - 3)).ProductId;
            system.debug('@@@@@@@@@'+cache.selProdId);
            landingPage = new PageReference('/apex/'+ pageToUrl +'?qId='+qId +'&displayName=N');
        }else if (pageToUrl == 'P2EvUploadDocuments'){
            //cache.selProdId = cache.allPlansMap.get(cache.allPlanIds.get(pageToId - 4)).ProductId;
            cache.selProdId = null;
            cache.selectedProduct = null;
            landingPage = new PageReference('/apex/'+ pageToUrl +'?qId='+qId +'&displayName=N');
        }
        try{
       //     cache.selProdId = null;
       //     cache.selectedProduct = null;
            saveCache();
        }
        catch(P2EException e){
            e.addSource('P2EcSelectedPlanDesign - pageNavigate()');
            e.logException();
        }   
        landingPage.setRedirect(true);
        return landingPage;
    }
    
    public PageReference pegaRFPRequest(){
        PageReference selectPage;
        try{ 
            if(cache.createdQuote.Date_Requested_by_AE__c == null){
                 ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: Date Requested by AE should be filled]');
                 ApexPages.addMessage(myMsg); 
                 return null; 
            }else if(cache.createdQuote.Date_Requested_by_AE__c < System.Today()){
                 ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: Date Requested by AE should not have back date]');
                 ApexPages.addMessage(myMsg); 
                 return null; 
            }else if(cache.createdQuote.Date_Requested_by_Group__c < cache.createdQuote.Date_Requested_by_AE__c ){
                 ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: Date Due to Group should be greater than Date Due to AE]');
                 ApexPages.addMessage(myMsg); 
                 return null;
            }else if(isallexisting==true && isSalesNoteAdded==false && cache.wizardType != null){
            
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: You cannot initiate Re-Rate or Negotiation without changing plan or adding sales notes]');
                 ApexPages.addMessage(myMsg); 
                 return null; 
            }else{
                if(Test.isRunningTest() && P2EhGlobalUtil.isNegScenario){
                    throw new P2EException('P2EcSelectedPlanDesign - pegaRFPRequest()','','Test','Manual');
                }
                System.debug('ttcase.Enrollment_Variation__c...........' + ttcase.Enrollment_Variation__c);
                if(ttcase.Enrollment_Variation__c == true){
                    Integer ttCaseCount = [SELECT COUNT() FROM Case WHERE Related_Opportunity__c =:OppId AND Enrollment_Variation__c = true AND Term_Transfer_Type__c!=null AND Term_And_Transfer__c = true AND Type = 'Term and Transfer' AND Quote__c = :quoteId];
                    
                    if(ttCaseCount==0){
                         ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: There should be at least one Term And Transfer Case created]');
                         ApexPages.addMessage(myMsg); 
                         return null; 
                    }
                }
                
                //Added for 2-way communication 
                if(oppt.Strategic_Info_Required__c == true && (oppt.Strategic_Pricing_Recommendations__c ==null || oppt.Priority_1__c == null || oppt.Priority_2__c == null || oppt.Priority_3__c == null || oppt.Priority_4__c == null || oppt.Priority_5__c == null)){
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: Strategic information is required on quote UI.]');
                        ApexPages.addMessage(myMsg); 
                }
                if(!cache.createdQuote.Claims_Experience_Received__c){
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'[Error: Claims Experience Received should be mandatory on quote UI.]');
                        ApexPages.addMessage(myMsg); 
                }
                if(ApexPages.hasMessages()){   
                    return null;
                }  
                //Till Here
                
                cache.selectedAccount = Database.Query(P2EhUtility.getQuery('Account') + ' where id = \''+ cache.selectedAccount.Id +'\' Limit 1');
                cache.selectedOpportunity = Database.Query(P2EhUtility.getQuery('Opportunity') + ' where id = \''+ cache.selectedOpportunity.Id +'\' Limit 1');
                 if(cache.selectedAccount.RecordTypeId == P2EhUtility.getRecordTypeId('Account', 'Prospect')){
                    cache.selectedAccount.RecordTypeId = P2EhUtility.getRecordTypeId('Account', 'Prospect Rate Impact');
                }
                else if(cache.selectedAccount.RecordTypeId == P2EhUtility.getRecordTypeId('Account', 'Customer')){
                    cache.selectedAccount.RecordTypeId = P2EhUtility.getRecordTypeId('Account', 'Customer Rate Impact');
                } 
                
                //Added for 2-way communication
                if(oppt.Strategic_Info_Required__c == true){
                        cache.selectedOpportunity.Strategic_Info_Required__c = oppt.Strategic_Info_Required__c;
                        cache.selectedOpportunity.Priority_1__c = oppt.Priority_1__c;
                        cache.selectedOpportunity.Priority_2__c = oppt.Priority_2__c;
                        cache.selectedOpportunity.Priority_3__c = oppt.Priority_3__c;
                        cache.selectedOpportunity.Priority_4__c = oppt.Priority_4__c;
                        cache.selectedOpportunity.Priority_5__c = oppt.Priority_5__c;
                        cache.selectedOpportunity.Strategic_Pricing_Recommendations__c = oppt.Strategic_Pricing_Recommendations__c;
                }//Till here     
                           
                P2EwWizCache rfpCache = P2EhWizardUtil.RFPCallout(cache,'UI');
                    if(rfpCache!=null){
                        cache = rfpCache;
                        if(cache.selectedopportunity.stagename == Label.Sales_Stages_Renewal_Initiated) {
                            subName = 'EarlyRenewal';
                           // cache.createdCase.Type = 'Renew';  //modified for 8019 row28
                            cache.createdCase.Type = 'RFP';
                        } else if(cache.selectedopportunity.AutoRenewal__c) {
                            subName = 'Production Renewal';
                        } else { subName = cache.selectedopportunity.Type; }
                        
                        if(cache.createdQuote.RFP_Case_Id__c != Null){
                            cache.createdCase.Subject = subName + ' RFP Case ID: ' + cache.createdQuote.RFP_Case_Id__c;   
                            cache.createdCase.Status = cache.createdQuote.RFP_Case_Status__c;
                            //Added by Srini
                            cache.createdCase.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                            //Added by Rushi
                            cache.createdCase.UW_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                            cache.createdCase.RFP_IMPLSubmittedBy__c = UserInfo.getUserId();
                            cache.createdCase.ownerId = UserInfo.getUserId();
                            if(cache.selectedopportunity.type == 'Renewal') {
                                //cache.selectedopportunity.stagename = 'Renewal Development';
                                cache.selectedopportunity.stagename = Label.Sales_Stages_Renewal_Development;// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Renewal_Development;// Changed for Sales Stage - Sujit
                            }else{
                                //cache.selectedopportunity.StageName = 'RFP Received / Proposal Development';
                                cache.selectedopportunity.StageName = Label.Sales_Stages_RFP_Response_Development;// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_RFP_Received_Proposal_Development;// Changed for Sales Stage - Sujit
                            }
                        }
                        //update Opportunity
                         
                        if(cache.createdQuote.RFP_Case_Status__c == 'Pending-Review' 
                                || cache.createdQuote.RFP_Case_Status__c == 'Resolved-Completed'){
                            if((cache.selectedopportunity.stagename != Label.Sales_Stages_Decision_won || cache.selectedopportunity.stagename != Label.Sales_Stages_Renewal_Decision_Won) 
                                    && cache.selectedopportunity.stagename != Label.Sales_Stages_Won){                        
                                if(cache.selectedopportunity.type == 'Renewal') {
                                //cache.selectedopportunity.stagename = 'Renewal Development';
                                cache.selectedopportunity.stagename = Label.Sales_Stages_Renewal_Development;// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Renewal_Development;// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.Probability = 75; 
                                }else{
                                //cache.selectedopportunity.StageName = 'RFP Received / Proposal Development';// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.StageName = Label.Sales_Stages_RFP_Response_Development;
                                cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_RFP_Received_Proposal_Development;// Changed for Sales Stage - Sujit
                                cache.selectedopportunity.Probability = 25; 
                                }                        
                                cache.selectedopportunity.ForecastCategoryName = 'Pipeline';                
                            }    
                        }                       
                        update cache.selectedOpportunity;
                        if(cache.createdQuote.RFP_Case_Status__c == null){                
                            ButtonType = false; 
                            ButtonValue = 'Negotiation';
                        }else{
                            ButtonType = true;
                            if(cache.createdQuote.RFP_Case_Status__c =='Pending-Review'){
                                ButtonValue = 'Negotiation';
                                cache.CreatedQuote.Status = 'In Progress';
                            }else if(cache.createdQuote.RFP_Case_Status__c =='Resolved-Completed' 
                                        || cache.createdQuote.RFP_Case_Status__c =='Completed'
                                        || cache.createdQuote.RFP_Case_Status__c =='Resolved Completed'){
                                ButtonValue = 'Re-Rate';
                                ButtonType = true;
                            }
                        }
                        Integer reRateProductCount;
                        Integer soldProductCount;                        
                        cache.selProdId = null;
                        cache.selectedProduct = null;
                        //To avoid plan updation after submitting RFP
                        P2EhGlobalUtil.comPlans = false;
                        P2EhGlobalUtil.comOlis = false;
                        P2EhGlobalUtil.comAO = false;
                        P2EhGlobalUtil.comCSTTs = false;
                        P2EhGlobalUtil.comRS = false;
                        //Since following both records are not updated by insertAll(). Updating Manually - parthi 07/11/2015
                        //Need to review. 07/11/2015 5:20PM                        
                        insertAll();
                        selectPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
                        selectPage.setRedirect(true);
                    }
               }
            }catch(Exception e){
                P2EException pe;
                String errorcode;
                Datetime cDT = System.now();
                errorcode = cDT.format('YYYYMMDDhhmmss');
                if(e instanceof P2EException){
                   pe = (P2EException)e;
                   if(pe.errorcode==null || pe.errorcode==''){
                       pe.errorcode = errorcode;
                   }
                   if(pe.stackTrace == null || pe.stackTrace==''){
                       pe.stackTrace = e.getStackTraceString();
                   }
                   pe.addSource('P2EcSelectedPlanDesign - pegaRFPRequest()');
                }
                else{ 
                   pe = new P2EException('P2EcSelectedPlanDesign - pegaRFPRequest()',errorcode,e);            
                    
                }
                pe.logException();
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please contact Administrator with ErrorCode: '+ pe.errorcode);
                ApexPages.addMessage(myMsg);  
                return null;                   
            }
            return selectPage;
        }               
           
    public PageReference addProduct(){
        cache.selProdId = null;
        cache.selectedProduct = null;
        cache.quickNaviMap.get(pageId).isLinkActive = true;
        cache.quickNaviMap.get(pageId).isCurrentScreen = false;
        
        try{
            saveCache();
        }
        catch(P2EException e){
            e.addSource('P2EcSelectedPlanDesign - addProduct()');
            e.logException();
        }
        PageReference searchPage = new PageReference('/apex/P2EvSearchPlanDesign?qId='+qId);
        searchPage.setRedirect(true);
        return searchPage;
    }
    
    private void loadSegments(){
        nameSegmentMap = new Map<String, Segmentation__c>();
        String segmentRecordType;
        if(cache.selectedOpportunity.Type == 'New'){
            segmentRecordType = 'Segment';
        }
        else{
            segmentRecordType = 'Division';
        }
        List<Segmentation__c> allSegments = [select id, name,Number_of_Eligible_Employees_for_Segment__c,Number_of_Total_Employees_for_Segments__c from Segmentation__c where Account__c =: cache.selectedAccount.Id and recordType.name =: segmentRecordType order by name asc limit 999  ];
        
        segmentNameList = new List<SelectOption>();
        segmentNameList.add(new SelectOption('None','None'));
        system.debug('Line 287'+segmentNameList);
        for(Segmentation__c seg : allSegments){
            segmentNameList.add(new SelectOption(seg.Id,seg.name));
            nameSegmentMap.put(seg.Id,seg);
        }
        availableProducts = new List<SelectOption>();
        for(P2EwPlanDesignLite wProduct : cache.allPlansMap.values()){
            system.debug(wProduct+'Line 482');
            if(wProduct.productId!=null && wProduct.planName!=null){
                availableProducts.add(new SelectOption(wProduct.productId, wProduct.planName));
            }
        }
        system.debug('Line 295'+availableProducts);
    }
    
    public string productToBeRemoved { get; set; }
    public string segmentToBeRemoved { get; set; }
    public PageReference removeSegment(){
        return null;
    }
    public PageReference addSegment(){
        PageReference selectPage2;
        system.debug('Line 306');
        try{
            if(selectedSegment == 'None'){
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please select a segment');
                ApexPages.addMessage(myMsg);
                system.debug('Line 310');
                ReloadSegment();      
                system.debug('Line 312');
                return null;
            }else if(segment == null){
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Null');
                ApexPages.addMessage(myMsg);
                return null;
            }else if(segment.Number_of_Eligible_Employees_for_Segment__c == null || segment.Number_of_Total_Employees_for_Segments__c == null){
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Null');
                ApexPages.addMessage(myMsg);
                return null;
            }else if(segment.Number_of_Eligible_Employees_for_Segment__c > segment.Number_of_Total_Employees_for_Segments__c){
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Eligible Primary Enrollees for segment should be less than Total Employees for segment');
                ApexPages.addMessage(myMsg);
                return null;
            }else{
                system.debug('selectedSegment..'+selectedSegment);
                system.debug('selectedProducts..'+selectedProducts);
                Set<String> selectedProdutsSet = new Set<String>();
                for(SelectOption prod : selectedProducts){
                    selectedProdutsSet.add(prod.getValue());
                }
                 system.debug('nameSegmentMap..'+nameSegmentMap);
                nameSegmentMap.get(selectedSegment).Number_of_Eligible_Employees_for_Segment__c = segment.Number_of_Eligible_Employees_for_Segment__c;
                nameSegmentMap.get(selectedSegment).Number_of_Total_Employees_for_Segments__c = segment.Number_of_Total_Employees_for_Segments__c;
                //try{
                    update nameSegmentMap.values();
                /*}catch(Exception e){
                    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Error,'Segment not added');
                    ApexPages.addMessage(myMsg);    
                }*/
                Map<Id, Product2> selProdMap = new Map<Id, Product2>();
                Segmentation__c segment = Database.Query(P2EhUtility.getQuery('Segmentation__c') + ' where id =: selectedSegment Limit 1');
                Set<Id> segments;
                for(Product2 prod : Database.Query(P2EhUtility.getQuery('Product2') + ' where id in: selectedProdutsSet')){
                    prodSegments.add(new ProdSegmentWrp(prod, segment));
                    if(cache.prodSegments.get(prod.Id)!=null){
                        segments = cache.prodSegments.get(prod.Id);
                    }else{
                        segments = new Set<Id>(); 
                    }
                    segments.add(segment.Id);
                    cache.prodSegments.put(prod.Id, segments);
                }
                
                ReloadSegment();
                  
                //try{
             saveCache();
             if(Test.isRunningTest() && P2EhGlobalUtil.isNegScenario){
                  throw new P2EException('P2EcSelectedPlanDesign - addSegment()','','Test','Manual');
             }
            /*}
            catch(P2EException e){
                    e.addSource('P2EcSelectedPlanDesign - addSegment()');
                    e.logException();
                }*/   
              //  return null;
            selectPage2 = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
            selectPage2.setRedirect(true);
                
        }
    }catch(Exception e){
            P2EException pe;
            String errorcode;
            Datetime cDT = System.now();
            errorcode = cDT.format('YYYYMMDDhhmmss');
            if(e instanceof P2EException){
               pe = (P2EException)e;
               if(pe.errorcode==null || pe.errorcode==''){
                   pe.errorcode=errorcode;   
               }
               if(pe.stackTrace == null || pe.stackTrace==''){
                   pe.stackTrace = e.getStackTraceString();
               }
               pe.addSource('P2EcSelectedPlanDesign - addSegment()');
            }
            else{ 
               pe = new P2EException('P2EcSelectedPlanDesign - addSegment()',errorcode,e);            
                
            }
            pe.logException();
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Segment not added. Please contact Administrator with ErrorCode: '+ pe.errorcode);
            ApexPages.addMessage(myMsg);  
            return null;                   
       }
       return selectPage2;     
 }
    private void reLoadSegment(){
        system.debug('Line 341');
        segment = new Segmentation__c();  
        selectedProducts.clear();
        selectedSegment='None'; 
        availableProducts = new List<SelectOption>();
        system.debug('Line 346'+availableProducts );
        for(P2EwPlanDesignLite wProduct : cache.allPlansMap.values()){
            availableProducts.add(new SelectOption(wProduct.planName, wProduct.planName));
        }
        system.debug('Line 350'+availableProducts );
    }
    
    //Method to send regret note if more information is not recevied from account
    public PageReference sendRegretNote(){
     Quote q= [Select OpportunityId from quote where id = :qId Limit 1];
        
        PageReference sendEmailPage = new PageReference('/apex/P2EvSendRegretNote?OppId='+q.OpportunityId );
        sendEmailPage.setRedirect(true);
        return sendEmailPage ;

    }
    
    public PageReference goToOppty(){ 
        if(cache.CreatedQuote.RFP_Case_Status__c == 'Resolved-Completed') {
            cache.CreatedQuote.Status='Completed';
            cache.selProdId = null;
            cache.selectedProduct = null;
              try{
         saveCache();
        }
        catch(P2EException e){
                e.addSource('P2EcSelectedPlanDesign - goToOppty()');
                e.logException();
            }   
            update cache.CreatedQuote;
        }
        return null;
    } 
    public PageReference updateDate(){
          try{
        cache.selProdId = null;
        cache.selectedProduct = null;
         saveCache();
        }
        catch(P2EException e){
                e.addSource('P2EcSelectedPlanDesign - updateDate()');
                e.logException();
            } 
        return null;    
    }
    public Boolean isChange { get; set; }
    
    public PageReference cloneQuote(){
        system.debug('line 1031'+cache.allPlansMap);
        PageReference selectPage;
        try{
            if(ButtonValue == 'Negotiation' || ButtonValue == 'Re-Rate'){
                if(cache.selectedopportunity.type =='Change'){
                cache.selectedOpportunity.stageName = Label.Sales_Stages_Change_Negotiation;
                cache.selectedOpportunity.Workflow_Stage__c = Label.Sales_Stages_Change_Negotiation;
                update cache.selectedOpportunity; 
                }
                cache.isRFPEnabled = true;   
                if(cache.isRFPEnabled || cache.createdQuote.Claims_Experience_Received__c){  //Added for 2-way communication
                     cache.createdQuote.Claims_Experience_Received__c = true;
                }//Till Here
                
                for(P2EwPlanDesignLite wpd1: cache.allPlansMap.values()){
                    if(ButtonValue == 'Negotiation'){
                        wpd1.isNegotiated=true;
                        wpd1.isOldPlan=true;
                    }else if(ButtonValue == 'Re-Rate'){
                        wpd1.isNegotiated=true;
                        wpd1.freezed = false;
                        wpd1.decision  = 'Decision Pending';
                        wpd1.isOldPlan=true;
                        cache.createdQuote.Is_Rerated_Quote__c=true;//added by Geetha for PC-13361
                        List<OpportunityLineItem> olilist1 = [Select Id, Action__c,Opportunity.type, Decision_Status__c, Parent_Impl_Case_Id__c, Product2Id, RFP_Case_Id__c, Parent_Impl_Case_Status__c, Group_Number__c From OpportunityLineItem 
                                Where OpportunityId =: cache.selectedOpportunity.Id and (Quote__c =: cache.createdQuote.Id or RFP_Case_Id__c =: cache.createdQuote.RFP_Case_Id__c)];
                         List<OpportunityLineItem> oliUpdateList = new List<OpportunityLineItem>();
                         system.debug('olilist1'+olilist1);
                         if(!olilist1.isEmpty()){
                             system.debug('into oli if'+olilist1);
                             /****@Geetha - 12052017 – ReImplementation Process Start****/
                             set<String> parImplCaseId=new set<String>();//Re-IMPL
                             set<String> parImplCaseStatus=new set<String>();//Re-IMPL
                             List<Integer> parImplCaseIdLst = new List<Integer>();//Re-IMPL 
                             String parImCaseToAssign = '';//Re-IMPL                                                        
                             Map<String,String> caseIdStatusMap = new Map<String,String>();//Re-IMPL
                             for(OpportunityLineItem oli1 : olilist1){
                                 if(oli1.Parent_Impl_Case_Id__c!=null && (oli1.Opportunity.type=='New' || oli1.Opportunity.type=='Change')){//last two conditions added for Re-IMPL
                                    cache.parentImplCaseId = oli1.Parent_Impl_Case_Id__c;
                                    cache.parentImplCaseStatus = oli1.Parent_Impl_Case_Status__c;
                                 }
                                 if(oli1.Parent_Impl_Case_Id__c!=null && (oli1.Opportunity.type=='Renewal')){//Re-IMPL start
                                    parImplCaseId.add(oli1.Parent_Impl_Case_Id__c); 
                                    parImplCaseStatus.add(oli1.Parent_Impl_Case_Status__c);  
                                    caseIdStatusMap.put(oli1.Parent_Impl_Case_Id__c,oli1.Parent_Impl_Case_Status__c);                                 
                                 }                                                                  
                             }
                                                          
                             if(parImplCaseId.size()>1){
                                if(parImplCaseStatus.size()==1){
                                    for(String caseId:parImplCaseId){
                                        parImplCaseIdLst.add(integer.valueof(caseId.remove('IM-')));
                                    }                                
                                    parImplCaseIdLst.sort();                                
                                    Integer lastIndex = parImplCaseIdLst.size()-1;                    
                                    parImCaseToAssign='IM-'+parImplCaseIdLst[lastIndex];                                
                                    cache.parentImplCaseId = parImCaseToAssign;
                                    cache.parentImplCaseStatus = caseIdStatusMap.get(parImCaseToAssign);                                
                                } 
                                else if(parImplCaseStatus.size()>1){
                                     for(OpportunityLineItem oli1 : olilist1){
                                         if(oli1.Parent_Impl_Case_Status__c=='Resolved-Completed'){
                                            cache.parentImplCaseId = oli1.Parent_Impl_Case_Id__c;
                                            cache.parentImplCaseStatus = oli1.Parent_Impl_Case_Status__c;
                                            break;
                                         }
                                     }
                                }    
                                        
                             }
                             else if(parImplCaseId.size()==1){
                                 for(String caseId:parImplCaseId){
                                     parImCaseToAssign=caseId;
                                 }
                                 cache.parentImplCaseId = parImCaseToAssign;
                                 cache.parentImplCaseStatus = caseIdStatusMap.get(parImCaseToAssign);
                             }//Re-IMPL End
                             /****@Geetha - 12052017 – ReImplementation Process End****/
                             for(OpportunityLineItem oli1 : olilist1){
                                 oli1.Decision_Status__c = 'Decision Pending';
                                 if(cache.parentImplCaseId!=null){
                                     oli1.IsRerate__c = true;
                                     oli1.Par_Impl_case_Id_Hide__c = cache.parentImplCaseId;
                                     oli1.Par_Impl_case_status_Hide__c = cache.parentImplCaseStatus;
                                 }
                                 oliUpdateList.add(oli1);
                             }
                         }
                         if(!oliUpdateList.isEmpty()){
                             update oliUpdateList;
                         }
                    }
                   }
                 
                     
                 cache.originalCaseId = cache.createdQuote.RFP_Case_Id__c;
                 cache.createdQuote.originalCaseId__c = cache.createdQuote.RFP_Case_Id__c;
                 if(ButtonValue == 'Negotiation'){
                     cache.wizardType='Negotiation';
                 }else if(ButtonValue == 'Re-Rate'){
                     cache.wizardType = 'Re-Rate';             
                 }
                 cache.createdQuote.RFP_Case_Id__c = null;
                 cache.createdQuote.RFP_Case_Status__c =null;
                 update cache.createdQuote;
                
                 system.debug(cache.originalCaseId+'Line 411');
                 ButtonType=false;
                 saveCache();
                selectPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
                selectPage.setRedirect(true);
                         
          }
          else{
                  String errorcode;
                  Datetime cDT = System.now();
                  errorcode = cDT.format('YYYYMMDDhhmmss');
                  throw new P2EException('P2EcSelectedPlanDesign - cloneQuote()',errorcode,'Button type not Re-Rate/Negotiation','Manual');
           }
           if(Test.isRunningTest() && P2EhGlobalUtil.isNegScenario){
                    throw new P2EException('P2EcSelectedPlanDesign - clonequote()','','Test','Manual');
           }
           }catch(Exception e){
                P2EException pe;
                String errorcode;
                Datetime cDT = System.now();
                errorcode = cDT.format('YYYYMMDDhhmmss');
                if(e instanceof P2EException){
                   pe = (P2EException)e;
                   if(pe.errorcode==null || pe.errorcode==''){
                       pe.errorcode=errorcode;
                   }
                   if(pe.stackTrace == null || pe.stackTrace==''){
                       pe.stackTrace = e.getStackTraceString();
                   }
                   pe.addSource('P2EcSelectedPlanDesign - cloneQuote()');
                }
                else{ 
                   pe = new P2EException('P2EcSelectedPlanDesign - cloneQuote()',errorcode,e);            
                    
                }
                pe.logException();
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please contact Administrator with ErrorCode: '+ pe.errorcode);
                ApexPages.addMessage(myMsg);  
                return null;                   
           }
       return selectPage;
    }
   
    
    public PageReference cloneSelectedProduct(){
        PageReference selectPage;
        Set<Id> selProdIds = new Set<Id>();
        try{
            for(String planIds : cache.allPlansMap.keySet()){
                if(cache.allPlansMap.get(planIds).selected){
                    selProdIds.add(cache.allPlansMap.get(planIds).productId);
                    //User can change only the existing plan
                    if(isChange && cache.allPlansMap.get(planIds).Action != 'Existing'){
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Error,'You can change only existing plans');
                        ApexPages.addMessage(myMsg);
                        return null;
                    }
                }
            }
            Integer oldCacheSize = cache.allPlansMap.size();
            cache = P2EhWizardUtil.cloneWPDCache(cache, selProdIds, true, isChange);
            cache.selProdId = null;
            cache.selectedProduct = null;
            cache.frameFullLink();
            insertAll();
            selectPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
            selectPage.setRedirect(true);
            if(Test.isRunningTest() && P2EhGlobalUtil.isNegScenario){
                    throw new P2EException('P2EcSelectedPlanDesign - cloneSelectedProduct()','','Test','Manual');
            }
        /*}catch(Exception e){
            system.debug(e);
        }*/
        }catch(Exception e){
            system.debug('e.getStackTraceString'+e.getStackTraceString());
            system.debug('e......'+e);
            P2EException pe;
            String errorcode;
            Datetime cDT = System.now();
            errorcode = cDT.format('YYYYMMDDhhmmss');
            if(e instanceof P2EException){
               pe = (P2EException)e;
               if(pe.errorcode==null || pe.errorcode==''){
                   pe.errorcode=errorcode;               
               }
               if(pe.stackTrace == null || pe.stackTrace==''){
                   pe.stackTrace = e.getStackTraceString();
               }
               pe.addSource('P2EcSelectedPlanDesign - cloneSelectedProduct()');
            }
            else{ 
               pe = new P2EException('P2EcSelectedPlanDesign - cloneSelectedProduct()',errorcode,e);                            
            }
            pe.logException();
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please contact Administrator with ErrorCode: '+ pe.errorcode);
            ApexPages.addMessage(myMsg);  
            return null;                   
       }
        
        return selectPage;
        //return null;
    }
    
    public PageReference renderSegment(){
        try{
        segment = nameSegmentMap.get(selectedSegment);
        if(Test.isRunningTest() && P2EhGlobalUtil.isNegScenario){
                    throw new P2EException('P2EcSelectedPlanDesign - renderSegment()','','Test','Manual');
        }
        
    }catch(Exception e){
            P2EException pe;
            String errorcode;
            Datetime cDT = System.now();
            errorcode = cDT.format('YYYYMMDDhhmmss');
            if(e instanceof P2EException){
               pe = (P2EException)e;
               if(pe.errorcode==null || pe.errorcode==''){
                   pe.errorcode=errorcode;               
               }
               if(pe.stackTrace == null || pe.stackTrace==''){
                   pe.stackTrace = e.getStackTraceString();
               }
               pe.addSource('P2EcSelectedPlanDesign - renderSegment()');
            }
            else{ 
               pe = new P2EException('P2EcSelectedPlanDesign - renderSegment()',errorcode,e);                            
            }
            pe.logException();
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please contact Administrator with ErrorCode: '+ pe.errorcode);
            ApexPages.addMessage(myMsg);  
            return null;                   
       }
        return null;
    }
    /*
    public PageReference cloneSelectedProduct(){
        P2EwWizPlanDesign clonedPlanDesign;
        P2EwWizProductSegment wProductSegment;
        P2EwWizCostShare wCostShare;
        Boolean hasSelected = false;
        Integer count = cache.clonedProducts.size();
        //Integer count = [select id from OpportunityLineItem where opportunityid =: cache.selectedOpportunity.id].size();
        for(P2EwPlanDesignLite wPlanDesignLite : allPlansMap.keySet()){
            if(wPlanDesign.selected){
                wPlanDesign.selected = false;
                //wPlanDesign.status = 'Completed';
                clonedPlanDesign = wPlanDesign.clone();
                clonedPlanDesign.product = wPlanDesign.product.clone();
                clonedPlanDesign.status = 'Open';
                clonedPlanDesign.isNegotiated = false;
                //clonedPlanDesign.Product.Action__c = 'Exising';
                  if(wPlanDesign.costShareList != null){
                      clonedPlanDesign.costShareList =  new List<P2EwWizCostShare>();
                      for(P2EwWizCostShare wCS : wPlanDesign.costShareList){
                          wCostShare = new P2EwWizCostShare(wCS.costShare.clone(), wCS.treatmentTypes.deepClone());
                          clonedPlanDesign.costShareList.add(wCostShare);
                      }
                  }
                  if(wPlanDesign.costShareListOriginal != null){
                      clonedPlanDesign.costShareListOriginal =  new List<P2EwWizCostShare>();
                      for(P2EwWizCostShare wCS : wPlanDesign.costShareListOriginal){
                          wCostShare = new P2EwWizCostShare(wCS.costShare.clone(), wCS.treatmentTypes.deepClone());
                          clonedPlanDesign.costShareListOriginal.add(wCostShare);
                      }
                  }
                clonedPlanDesign.rateSheetList = new List<P2EwWizRateSheets>();
                P2EwWizRateSheets requestRateSheet = new P2EwWizRateSheets();
                RateSheet__c reqRateSheet = new RateSheet__c(Type__c = 'Request');
                requestRateSheet.rateSheet = reqRateSheet;
                requestRateSheet.prodSegments = null;
                requestRateSheet.originalRates = new List<Rates__c>();
                requestRateSheet.adminRates = new List<Rates__c>();
                if(!isChange){
                    if(clonedPlanDesign.product.Funding_Arragements__c.equals('ASC (Self funded)')){
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Current Fee'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Commission'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Renewal Fee'));
                    }else if(clonedPlanDesign.product.Funding_Arragements__c.equals('ASC with Stop Loss')){
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Both', AdminAnalysis__c = 'Net Current Fee'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Both', AdminAnalysis__c = 'Commission'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Renewal Fee'));
                    }                    
                    clonedPlanDesign.rateSheetList.add(requestRateSheet);   
                }
              system.debug('change***'+isChange);
              clonedPlanDesign.Product.Sold__c= 'Decision Pending';
              if(isChange){
                 System.debug('wPlanDesign.product.Action__c' + wPlanDesign.product.Action__c ); 
                 if(wPlanDesign.product.Action__c != 'New' && wPlanDesign.product.Action__c != 'Update'){
                      clonedPlanDesign.Product.Action__c = 'Update';
                      //clonedPlanDesign.Product.Group_Number__c =null;
                      wPlanDesign.product.Action__c = 'Delete';
                      clonedPlanDesign.product.name += ' - Change';
                      //clonedPlanDesign.product.NegotiationDummy__c = 'InActive';
                      system.debug('old plan design id***'+wPlanDesign.product.Id);
                      clonedPlanDesign.product.OldPlanDesign__c = wPlanDesign.product.Id;
                      clonedPlanDesign.product.PlanID__c = String.valueOf(count + 1);
                      wPlanDesign.product.Freezed__c = true;
                      
                      
                      
                      
                     if((clonedPlanDesign.product.Funding_Arragements__c.equals('ASC (Self funded)') || 
                        clonedPlanDesign.product.Funding_Arragements__c.equals('ASC with Stop Loss'))){
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Current Fee'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Commission'));    
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Renewal Fee'));                   
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Total Enrollees'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Projected Paid Claims'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Incremental'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Required (full) Cars'));                       
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Proposed'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Total Proposed'));  
                            if(cache.selectedOpportunity.Type == 'Renewal'){
                                requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Renewal Justification'));  
                                requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Net Justified Fee'));  
                            }
                      }else if((clonedPlanDesign.product.Funding_Arragements__c.equals('Non-Retention (Non-Participating)')) || 
                    (clonedPlanDesign.product.Funding_Arragements__c.equals('Retention (Participating)')) || 
                    (clonedPlanDesign.product.Funding_Arragements__c.equals('Guaranteed Administration (Participating)')) || 
                    (clonedPlanDesign.product.Funding_Arragements__c.equals('Guaranteed Administration (Participating)')) ){
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Incremental'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Full CARS'));
                        requestRateSheet.adminRates.add(new Rates__c(RateType__c = 'Admin', AdminAnalysis__c = 'Proposed Admin')); 
                    }   
                      clonedPlanDesign.rateSheetList.add(requestRateSheet);
                      
                      
                      
                      
                      
                      
                 }else if(wPlanDesign.product.Action__c == 'New' || wPlanDesign.product.Action__c == 'Update'){
                      ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'You cannot change new/updated plan.'));
                      return null;
                 }
              }
              else{
                  clonedPlanDesign.Product.Action__c = 'New';
                  clonedPlanDesign.Product.Group_Number__c = null;
                  clonedPlanDesign.product.name += ' - Cloned';  
                  //clonedPlanDesign.product.NegotiationDummy__c = 'InActive';               
                  clonedPlanDesign.product.OldPlanDesign__c = wPlanDesign.product.Id;
                  clonedPlanDesign.product.PlanID__c = String.valueOf(count + 1);                
               // clonedPlanDesign.product.Benefit_Package_Id__c = null;
              }
              if(wPlanDesign.product.Action__c == 'Delete' && wPlanDesign.product.Freezed__c == true){
                     wPlanDesign.product.Sold__c = 'Not - Sold';
              }
              
              wPlanDesign.product.Implemented__c = false;
              clonedPlanDesign.product.Implemented__c = false;
              
              clonedPlanDesigns.add(clonedPlanDesign);
              }
              count=count+1;
             
          }
          
          cache.clonedProducts.addAll(clonedPlanDesigns);
          //system.debug('Cloned Products***'+cache.clonedProducts);
          cache.frameFullLink();
          try{
              insertAll();
              System.debug('INSIDE TRY**' + cache.clonedproducts);
              PageReference selectedPlanDesignPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
              selectedPlanDesignPage.setRedirect(true);
              return selectedPlanDesignPage;
          }
          catch(Exception e){
              ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,e.getMessage()));
              return null;
          }
          init();
          return null;
      }
      */
      
    public class ProdSegmentWrp {
        public Product2 product { get; set; }
        public Segmentation__c segment { get; set; }
        public ProdSegmentWrp(Product2 product, Segmentation__c segment){
            this.product = product;
            this.segment = segment;
        }
    }
    
     public void mSaveQuote(){      
     
        system.debug(cache.createdQuote.Id);        
        savecache();        
        update cache.createdQuote;   
               
    }
    
    public PageReference addNotes(){
        if(salesNotes == null || salesNotes == ''){ 
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please add SalesNotes');
            ApexPages.addMessage(myMsg);
            return null;
        }
        if(salesNotes != null){
            /****@Jaleel - 10122017 - RichTextArea Requirement****/
            /*note = new Note();
            note.Title = 'SalesNotes';
            note.Body= salesNotes;
            note.ParentId = cache.createdQuote.Id;
            insert note; */
            //noteToDisplay = [select id,body,ParentId,title,createdById,createdDate,CreatedBy.name from note where ParentId =:cache.createdquote.Id order by createdDate desc];
            
            Implementation_Notes__c salesNote = new Implementation_Notes__c(Implementation_Notes__c=salesNotes, Quote__c=cache.createdQuote.Id, RecordTypeId=salesNoteRecordTypeId);
            insert salesNote;
            
            noteToDisplay = new List<Implementation_Notes__c>([Select Id, CreatedDate, CreatedBy.Name, Implementation_Notes__c from Implementation_Notes__c where Quote__c=:cache.createdQuote.Id and RecordTypeId=:salesNoteRecordTypeId order by createdDate desc]);
            salesNoteToDisplay.clear();//UWNotes Start
            for(Implementation_Notes__c Notes:noteToDisplay){//UWNotes Start
                if(Notes.Implementation_Notes__c!=null && Notes.RecordTypeId==salesNoteRecordTypeId){
                    salesNoteToDisplay.add(Notes);
                }
            }//UWNotes End
            /****@Jaleel - 10122017 - End of RichTextArea Requirement****/

            cache.createdquote.Sales_Notes__c = salesNotes;
            salesNotes = Null;
            isSalesNoteAdded=true;
            system.debug('sales*** '+cache.createdquote.Sales_Notes__c);
            savecache();
        }
        return null;
     }
     
    public PageReference withdrawChanges(){
        //Added for PC-12024
        PageReference selectedPlanDesignPage;
        if(cache.createdQuote.RFP_Case_Id__c != null || cache.createdQuote.originalcaseid__c != null){
            P2EhPegaCallouts pega = new P2EhPegaCallouts(cache.createdQuote);
        }
        //Upto this for PC-12024
        try{
            cache.selProdId = null;
            cache.selectedProduct = null;
            Set<Id> qtids = new Set<Id>();
            qtids.add(cache.createdQuote.Id);                    
            P2EhUtility.withdrawfunc(qtids);
            cache.createdQuote.Status = 'Withdrawn';
            //Added for PC-12024
            cache.createdQuote.RFP_Case_Status__c = 'Resolved-Withdrawn';
            update cache.createdQuote;  
            savecache();                      
            loadcache();
            //Upto this for PC-12024
            //Added for Term and Transfer - START
            if(ttcases.size()>0){
                delete ttcases;
            }//END
            selectedPlanDesignPage = new PageReference('/apex/P2EvSelectedPlanDesign?qId='+qId);
            selectedPlanDesignPage.setRedirect(true); 
                 
       }catch(Exception e){
            P2EException pe;
            String errorcode;
            Datetime cDT = System.now();
            errorcode = cDT.format('YYYYMMDDhhmmss');
            if(e instanceof P2EException){
               pe = (P2EException)e;
               if(pe.errorcode==null || pe.errorcode==''){
                   pe.errorcode=errorcode;               
               }
               if(pe.stackTrace == null || pe.stackTrace==''){
                   pe.stackTrace = e.getStackTraceString();
               }
               pe.addSource('P2EcSelectedPlanDesign - withdrawChanges()');
            }
            else{ 
               pe = new P2EException('P2EcSelectedPlanDesign - withdrawChanges()',errorcode,e);                            
            }
            pe.logException();
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please contact Administrator with ErrorCode: '+ pe.errorcode);
            ApexPages.addMessage(myMsg);  
            return null;                   
       }
       return selectedPlanDesignPage;
   }    
    @TestVisible private List<P2EwWizPlanDesign> loadWPDCache(Set<Id> prodIds){
        List<P2EwWizPlanDesign> allPlansWPD = new List<P2EwWizPlanDesign>();
        List<WPDCache__c> wpdList = Database.Query(P2EhUtility.getQuery('WPDCache__c') + ' where Product__c =: prodIds order by PartNumber__c ASC');
        String jsonStr;
        Map<Id, String> prodWPD = new Map<Id, String>();
        for(WPDCache__c wpd : wpdList){
            if(prodWPD.get(wpd.Product__c)!=null){
                jsonStr = prodWPD.get(wpd.Product__c);
            }else{
                jsonStr = '';
            }
            jsonStr += wpd.WPDJSON__c;
            prodWPD.put(wpd.Product__c, jsonStr);
        }
        for(Id prodId : prodWPD.keyset()){
            allPlansWPD.add((P2EwWizPlanDesign) System.JSON.deserialize(prodWPD.get(prodId), P2EwWizPlanDesign.class));
        }
        return allPlansWPD;
    }
    
    public void delRow()
    {
        id se=segsids;
        id proid=pro;              
        system.debug('segid'+segsids);     
        Segmentation__c  seg2=[select id from Segmentation__c where id =:se limit 1];
        product2 pr=[select id from product2 where id=:proid limit 1];
        system.debug('selist'+seg2);     
        system.debug('sss'+cache.prodSegments);
        try{
            cache.prodSegments.get(pr.id).remove(seg2.id); 
            saveCache(); 
        }catch(P2EException e){
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Info,'segment not deleted');
            ApexPages.addMessage(myMsg);
        }  
    }
    
    /*** Added by Murali for Missing BP Solution(PC-15498) on 9/28/17 - Start ***/
    //Display the Benefit Package ID list on Pop-up
    public PageReference getBPList(){ 
        system.debug('selPlanIdN'+selPlanIdN);          
        //prdBenLst = [select id,Benefit_Package__c,Benefit_Package_ID__c,Product__c from ProdBenefit__c where Product__r.Id =: selProdId];
        prdBenLst=ProdBPMap.get(selPlanIdN); 
        system.debug('prdBenLst'+prdBenLst);          
        displayPopup = true;
        return null;
    }
    //Close the pop-up
    public PageReference closePopup(){
        displayPopup = false;
        return null;
    }
    /*** PC-15498 End ***/
    
}