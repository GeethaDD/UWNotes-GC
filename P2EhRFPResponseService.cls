/*
 * @description 
 * 
 * @author
 *
 * @change Hitendar  10/26/2015 Used the utility class to get the record type instead of querying
 * @change Parthiban 10/27/2015 Auto Sold and Auto Impl will not happen for rerated and negotiated quote
 * @change Rajesh    12/18/2015 Auto Sold and Auto Impl in Renewal opportunity, Quote status is displaying as "In Progress" instead of "Completed"
 * @change HCL       08/15/2016 Added new fields to support 5 Billing spans
 * @change HCL       09/02/2016 Added logic to add back Segments for Ratesheets back in Salesforce 
 * @Change Issac Pal C 14/02/2019 - SF001 Response Parsing - Added new logic to implement the new Json Ratesheet Structure
 */ 

public with sharing class P2EhRFPResponseService extends P2EaWizCacheProcess {
    private List<P2EwService.ServiceError> errorList;
    private P2EwService.SF001Request req;
    private Map<String, P2EwPegaService.QQPlans> resPlanMap;
    private Map<String, Product2> allPlansWPD;
    private Boolean isAutoIMPL;
    private Boolean isDecisionSold;
    private Id uwNoteRecordTypeId;//added for UWNotes
    public Boolean isResClonedPlans;
    public Set<String> removePlans;
    private Set<String> osrPlanIds;
    private Map<String, Id> allPlanPId;
    //Variable to store the rateComparision
    public Map<String, Boolean> rateCompareMap = new Map<String, Boolean>();
    public P2EhRFPResponseService(){
        errorList = new List<P2EwService.ServiceError>();
        osrPlanIds = new Set<String>();
        allPlanPId = new Map<String, Id>();
        removePlans = new Set<String>();
        isSF001 = true;
        P2EhGlobalUtil.updateOnlyRateSheets = new Map<String, Boolean>();
        P2EhGlobalUtil.updateCSnTTs = new Map<String, Boolean>();
    }
    
    public P2EwService.SF001Response sf001(P2EwService.SF001Request req){
        System.debug('Inside sf001 method ***' + Limits.getHeapSize());
        try{
            if(req==null){
                errorList.add(new P2EwService.ServiceError('SF001-00','Request received as Null.'));
                return new P2EwService.SF001Response('Error', errorList);
            }else if(req.CaseID==null){
                errorList.add(new P2EwService.ServiceError('SF001-00','Required field missing in Request - CaseID'));
                return new P2EwService.SF001Response('Error', errorList);
            }else if(req.CaseStatus==null){
                errorList.add(new P2EwService.ServiceError('SF001-00','Required field missing in Request - CaseStatus'));
                return new P2EwService.SF001Response('Error', errorList);
            }else{
                this.req = req;
                Quote quot;
                Opportunity opp;
                Account acc;
                List<WizardCache__c> wizCacheList;
                String reqCaseStatus;
                
                try{
                    quot = [select Id, Name, RFP_Case_Id__c, RFP_Case_Status__c, originalcaseid__c, OpportunityId from Quote where RFP_Case_Id__c =: req.CaseID OR originalcaseid__c =: req.CaseID Limit 1];
                }catch(QueryException e){
                    P2EhGlobalUtil.ServiceErrorCde = 'SF001-01';
                    P2EhGlobalUtil.ServiceErrorMsg = 'Quote not found in salesforce. Please contact Administrator.';
                    //P2EhGlobalUtil.ServiceErrorMsg = 'Negotiation is in-progress with the group. Please work with sales to resolve-complete this case.';
                    //errorList.add(new P2EwService.ServiceError('SF001-00','Negotiation is in-progress with the group. Please work with sales to resolve-complete this case.'));
                    errorList.add(new P2EwService.ServiceError('SF001-00','Quote not found in salesforce. Please contact Administrator.'));
                    return new P2EwService.SF001Response('Error', errorList);
                }catch(Exception e){
                    P2EhGlobalUtil.ServiceErrorCde = 'SF001-01';
                    P2EhGlobalUtil.ServiceErrorMsg = 'Quote not found in salesforce. Please contact Administrator.';
                    //P2EhGlobalUtil.ServiceErrorMsg = 'Negotiation is in-progress with the group. Please work with sales to resolve-complete this case.';
                    //errorList.add(new P2EwService.ServiceError('SF001-00','Negotiation is in-progress with the group. Please work with sales to resolve-complete this case.'));
                    errorList.add(new P2EwService.ServiceError('SF001-00','Quote not found in salesforce. Please contact Administrator.'));
                    return new P2EwService.SF001Response('Error', errorList);
                }
                if(quote.RFP_Case_Id__c == Null && quote.originalcaseid__c != NULL){
                    P2EhGlobalUtil.ServiceErrorCde = 'SF001-01';                    
                    P2EhGlobalUtil.ServiceErrorMsg = 'Negotiation/Re-Rate is in-progress. Please work with sales to resolve-complete this case.';
                    errorList.add(new P2EwService.ServiceError('SF001-00','Negotiation is in-progress. Please work with sales to resolve-complete this case.'));
                    return new P2EwService.SF001Response('Error', errorList);                
                }               
                if(quot != Null){
                    try{
                        opp = [Select Id, Name, OwnerId ,AccountId From Opportunity where Id =: quot.OpportunityId Limit 1];
                    }catch(Exception e){
                        P2EhGlobalUtil.ServiceErrorCde = 'SF001-02';
                        P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                        throw new P2EException('P2EhRFPResponseService - sf001','', e);
                    }
                    
                    try{
                        acc = [Select Id, Name from Account where Id =: opp.AccountId Limit 1];
                    }catch(Exception e){
                        P2EhGlobalUtil.ServiceErrorCde = 'SF001-04';
                        P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                        throw new P2EException('P2EhRFPResponseService - sf001','', e);
                    }
                    qId = quot.Id;
                }
                
                System.debug('Before Load Cache ***'+Limits.getHeapSize());
                try{
                    loadCache();
                }catch(P2EException e){
                    e.addSource('P2EhRFPResponseService - sf001');
                    e.logException();
                    errorList.add(new P2EwService.ServiceError('SF001-03','Service Failed. Contact Administrator.'));
                    system.debug('loadCache failed');
                    system.debug(e.getMessage());
                    throw e;
                }catch(Exception e){
                    P2EhGlobalUtil.ServiceErrorCde = 'SF001-03';
                    P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                    throw new P2EException('P2EhRFPResponseService - sf001','', e);
                }
                
                System.debug('After load Cache ***'+Limits.getHeapSize());
                System.Savepoint sp = Database.setSavepoint();
                
                if(cache!=null){
                    cache.selProdId = null;
                    cache.selectedProduct = null;
                    // Already Resolved Completed
                    /*if(cache.createdQuote.RFP_Case_Status__c == 'Resolved-Completed'){
                        errorList.add(new P2EwService.ServiceError('SF001-00','RFP Case '+req.CaseID+' has already been resolved completed'));
                        return new P2EwService.SF001Response('Error', errorList);
                    }*/
                    
                    //Update RFP Case Status
                    cache.createdQuote.RFP_Case_Status__c = req.CaseStatus;
                    cache.createdQuote.RFP_Case_Id__c = req.CaseID;
                    
                    //Update Cache's Created Case's Status
                    if(cache.createdCase!=null){
                        cache.createdCase.Status = req.CaseStatus;
                    }
                    
               /*     //Update change opportunity stage name
                    if(cache.selectedopportunity.type == 'Change' && cache.createdQuote.RFP_Case_Id__c != Null) {
                       // cache.selectedopportunity.stagename = 'Inprogress';
                       cache.selectedopportunity.stagename = 'Change Initiated';
                    } */
                    
                    //System.Savepoint sp = Database.setSavepoint();
                    if(req.Proposal!=null){
                        //Opportunity Field update
                        //List<Product2> prodlist = new list<Product2>();
                        //String UWNotes;//commented for UWNotes
                        Boolean isOpportunityUpdate = false;  //Added for Lives change
                        System.debug('Before req.Proposal processing ***'+Limits.getHeapSize());
                        if(req.Proposal.Opportunity!=null){
                            //UWNotes = req.Proposal.Opportunity.UWNotes;//commented for UWNotes
                            
                            if(req.Proposal.Opportunity.UWNotesList!=null){//UWNotes Start
                                uwNoteRecordTypeId = Schema.SObjectType.Implementation_Notes__c.getRecordTypeInfosByName().get('UW Notes').getRecordTypeId();
                                List<Implementation_Notes__c> uwNotesToInsert=new List<Implementation_Notes__c>();
                                for(P2EwPegaService.QQUWNotes uwnotes:req.Proposal.Opportunity.UWNotesList){
                                    Implementation_Notes__c uwnt=new Implementation_Notes__c();
                                    uwnt.Title__c='UW Notes'; 
                                    uwnt.Quote__c=quot.Id;
                                    uwnt.UW_Notes__c=EncodingUtil.base64Decode(uwnotes.Notes).toString();
                                    uwnt.RecordTypeId=uwNoteRecordTypeId;
                                    if(uwnotes.pxCreateDateTime != null){                                        
                                        integer year = integer.valueof(uwnotes.pxCreateDateTime.substring(0,4));
                                        integer month = integer.valueof(uwnotes.pxCreateDateTime.substring(4,6));
                                        integer day =  integer.valueOF(uwnotes.pxCreateDateTime.substring(6,8));
                                        integer hour= integer.valueOF(uwnotes.pxCreateDateTime.substring(9,11));
                                        integer minute= integer.valueOF(uwnotes.pxCreateDateTime.substring(11,13));
                                        integer second= integer.valueOF(uwnotes.pxCreateDateTime.substring(13,15));
                                        //uwnt.UW_Notes_Created_Date__c = Date.newinstance(year,month,day );  
                                        uwnt.UW_Notes_Created_Date__c = DateTime.newInstanceGMT(year,month,day,hour,minute,second);                                      
                                    }
                                    //uwnt.UW_Notes_Created_Date__c=uwnotes.pxCreateDateTime;
                                    uwnt.UW_Notes_UserName__c=uwnotes.pyUserName;
                                    uwNotesToInsert.add(uwnt);
                                }   
                                if(uwNotesToInsert.size()>0){
                                    insert uwNotesToInsert;
                                }
                            }//UWNotes End
                            
                            //Added for IF401/Lives change
                            system.debug('CurrentFFSSubscribers Req:'+req.Proposal.Opportunity.CurrentFFSSubscribers);
                            if(req.Proposal.Opportunity.CurrentFFSSubscribers !=null){
                                cache.selectedOpportunity.FFS_Number_of_Current_Primary_Enrollees__c = req.Proposal.Opportunity.CurrentFFSSubscribers;   
                                isOpportunityUpdate = true;
                            }  
                            if(req.Proposal.Opportunity.CurrentDHMOSubscribers !=null){
                                cache.selectedOpportunity.DHMO_Number_of_Current_Primary_Enrollees__c = req.Proposal.Opportunity.CurrentDHMOSubscribers; 
                                isOpportunityUpdate = true;
                            }
                            // Till here for IF401/Lives change
                            //Added for IF401/Lives change
                            system.debug('EligiblePrimaryEnrollees Req:'+req.Proposal.Opportunity.EligiblePrimaryEnrollees);
                            if(req.Proposal.Opportunity.EligiblePrimaryEnrollees !=null){ //IF401 Dec Release
                                cache.selectedOpportunity.No_of_Enrollees__c = req.Proposal.Opportunity.EligiblePrimaryEnrollees;   
                                isOpportunityUpdate = true;
                            } //Till here for IF401 Dec Release
                            
                            //Added for 2-Way Communication
                            Map<String,Credit__c> creditMap = new Map<String,Credit__c>([SELECT Id,Name,Frequency__c,Granted_Amount__c,Opportunity__c,PEPM_or_Dollar__c,Requested_Amount__c,Sales_Notes__c,Status__c,Type_of_Credit__c,UW_Notes__c FROM Credit__c Where Opportunity__c=:cache.selectedOpportunity.Id]);
                            System.debug('creditMap###'+ creditMap);
                            List<Credit__c> creditsToUpsert = new List<Credit__c>();
                                              
                            if(req.Proposal.Opportunity.CreditDetails!=null){
                                for(P2EwPegaService.QQCreditDetails cred : req.Proposal.Opportunity.CreditDetails){
                                    if(cred.creditID != null && cred.creditID != '' && creditMap.containsKey(cred.creditID)){
                                        Credit__c creditExist = creditMap.get(cred.creditID);
                                        creditExist.UW_Notes__c = cred.UWNotes;
                                        /* if(cred.UWNotes !=null && cred.UWNotes !=''){  //Commented since PEGA has not Encoded/Decoded the value
                                            creditExist.UW_Notes1__c = EncodingUtil.base64Decode(cred.UWNotes).toString();
                                        } */
                                        if(cred.GrantedAmount !=null && cred.GrantedAmount !=''){
                                            creditExist.Granted_Amount__c = Decimal.valueOf(cred.GrantedAmount);
                                            creditExist.Status__c = 'Approved';
                                        }
                                        creditsToUpsert.add(creditExist);
                                    }else{
                                        Credit__c newCredit = new Credit__c();
                                        newCredit.Frequency__c=cred.Frequency;
                                        newCredit.Opportunity__c=cache.selectedOpportunity.Id;
                                        newCredit.PEPM_or_Dollar__c=cred.PEPMorDollar;
                                        newCredit.Sales_Notes__c = cred.SalesNotes;
                                        newCredit.UW_Notes__c = cred.UWNotes;
                                        /* //Commented since PEGA has not Encoded/Decoded the value//
                                        if(cred.SalesNotes !=null && cred.SalesNotes !=''){  
                                            newCredit.Sales_Notes1__c = EncodingUtil.base64Decode(cred.SalesNotes).toString();
                                        }
                                        if(cred.UWNotes !=null && cred.UWNotes !=''){
                                            newCredit.UW_Notes1__c = EncodingUtil.base64Decode(cred.UWNotes).toString();
                                        }*/
                                        
                                        if(cred.Amount !=null && cred.Amount !=''){
                                            newCredit.Requested_Amount__c = Decimal.valueOf(cred.Amount);
                                        }
                                        if(cred.GrantedAmount !=null && cred.GrantedAmount !=''){
                                            newCredit.Granted_Amount__c = Decimal.valueOf(cred.GrantedAmount);
                                            newcredit.Status__c = 'Approved';
                                        }
                                        if(cred.Type =='Others'){
                                            cred.Type = 'Other credits';
                                        }
                                        newcredit.Type_of_Credit__c=cred.Type;
                                        creditsToUpsert.add(newCredit);
                                    }
                                }
                            } //Till here for 2-way communication
                            
                            //PC-16759 Start
                            try{ //Till here for IF401 Dec Release
                                if(isOpportunityUpdate){    //Added for Lives change
                                    update cache.selectedOpportunity; 
                                }
                                if(creditsToUpsert.size()>0){  //Added for 2-way communication
                                    upsert creditsToUpsert;
                                }
                            }catch(P2EException e){
                                e.addSource('P2EhRFPResponseService- sf001()');
                                //e.logException();
                                Database.rollback(sp);
                                P2EhGlobalUtil.ServiceErrorCde = 'SF001-010';
                                P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                                throw e;
                            }//Till here for PC-16759
                        }
                        String SitusState;
                        if(req.Proposal.Account!=null){
                            if(req.Proposal.Account.SitusState == null || req.Proposal.Account.SitusState == ''){
                                errorList.add(new P2EwService.ServiceError('SF001-05','Required Fields Missing. SitusState is required in the request.'));
                                Database.rollback(sp);
                                return new P2EwService.SF001Response('Error', errorList);
                            }
                            else{
                                cache.selectedAccount.Situs_State__c = req.Proposal.Account.SitusState;   
                            }
                             
                        }
                        
                        //Add the new plan sent by UW to cache
                        Integer count;
                        List<P2EwWizPlanDesign> allPlans = new List<P2EwWizPlanDesign>();
                        isResClonedPlans = false;
                        isAutoIMPL = false;
                        isDecisionSold = false;
                        if(req.Proposal.Plans!=null){
                            resPlanMap = new Map<String, P2EwPegaService.QQPlans>();
                            //isResClonedPlans = false;
                            List<P2EwPegaService.QQPlans> resClonedPlans = new List<P2EwPegaService.QQPlans>();
                            count = req.Proposal.Plans.size();
                            //allPlansWPD = fetchAllWPD();
                            Set<id> prodIds = new Set<id>();
                            for(P2EwPlanDesignLite pdl : cache.allPlansMap.values()){
                                prodIds.add(pdl.ProductId);
                            }
                            allPlansWPD = new Map<String, Product2>();
                            for(Product2 prod : [select id, planId__c, UWQuestionnaire__c, Implementation_Notes__c, Benefit_Notes__c from Product2 where id in: prodIds]){
                                allPlansWPD.put(prod.planId__c, prod);
                            }

                            List<OpportunityLineItem> oliLst = [select id,PlanID__c from OpportunityLineItem where OpportunityId =: cache.selectedOpportunity.Id];
                            Integer pcount = oliLst.size(); //resPlanMap.size()
                            system.debug('Line 190');
                            for(P2EwPegaService.QQPlans respPlan : req.Proposal.Plans){
                                /*if((respPlan.PlanID==null || respPlan.PlanID=='') && (respPlan.ClonedPlanID==null || respPlan.ClonedPlanID=='') && respPlan.OSRPlanId!=null){
                                    respPlan.PlanID = String.valueOf(pcount);
                                    resClonedPlans.add(respPlan);
                                    pcount++;
                                }*/
                                if((respPlan.PlanID==null || respPlan.PlanID=='') && (respPlan.ClonedPlanID==null || respPlan.ClonedPlanID=='') && (respPlan.OSRPlanId!=null || respPlan.OSRPlanId!='')){
                                    /*for(OpportunityLineItem oli1:oliLst){
                                        if(oli1.PlanID__c == String.valueOf(pcount)){
                                            pcount++;
                                            respPlan.PlanID = String.valueOf(pcount);
                                        }
                                        else{
                                            respPlan.PlanID = String.valueOf(pcount);
                                        }
                                    }
                                    
                                    pcount++;*/
                                    respPlan.PlanID =String.valueOf(Math.floor(Math.random()*(9999999-2500000+1))+2500000).subString(0,7);//13674
                                    resClonedPlans.add(respPlan);
                                }
                                system.debug('Line 198');
                               /* Need to check
                               else
                                {
                                 if(respPlan.Product2ID == null || respPlan.Product2ID== ''){
                                        errorList.add(new P2EwService.ServiceError('SF001-06','Required Fields Missing for the Product - Product2ID'));
                                        Database.rollback(sp);
                                        return new P2EwService.SF001Response('Error', errorList);
                                    }
                                } */
                               /* if(respPlan.PlanID!=null && respPlan.PlanID!='' && respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='' && cache.wizardType != 'Re-Rate'){
                                    errorList.add(new P2EwService.ServiceError('SF001-00','Both PlanID & ClonedPlanID are available in Request'));
                                    Database.rollback(sp);
                                    return new P2EwService.SF001Response('Error', errorList);
                                } */
                                /*if(((respPlan.PlanID!=null && respPlan.PlanID!='') 
                                     && (respPlan.ClonedPlanID==null || respPlan.ClonedPlanID==''))||(respPlan.PlanID!=null && respPlan.PlanID!='' && respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='' && cache.wizardType != 'Re-Rate'))){*/
                                    if(respPlan.PlanID!=null && respPlan.PlanID!=''){//Commented the above condition and added new condition by Geetha for PC-16835 
                                    resPlanMap.put(respPlan.PlanID, respPlan);
                                    //insert/update only ratesheets for these plans
                                    P2EhGlobalUtil.updateOnlyRateSheets.put(respPlan.PlanID, true);
                                    P2EhGlobalUtil.updateCSnTTs.put(respPlan.PlanID, false);
                                }
                                /*if(((respPlan.PlanID==null || respPlan.PlanID=='') 
                                     && (respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='') && respPlan.OSRPlanId!=null)||(respPlan.PlanID!=null && respPlan.PlanID!='' && respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='' && cache.wizardType != 'Re-Rate' && respPlan.OSRPlanId!=null)){
                                    respPlan.PlanID = String.valueOf(pcount);
                                    resClonedPlans.add(respPlan);
                                    pcount++;
                                }*/
                                if(((respPlan.PlanID==null || respPlan.PlanID=='') 
                                     && (respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='') && respPlan.OSRPlanId!='')||(respPlan.PlanID!=null && respPlan.PlanID!='' && respPlan.ClonedPlanID!=null && respPlan.ClonedPlanID!='' && cache.wizardType != 'Re-Rate' && respPlan.OSRPlanId!='')){
                                    /*for(OpportunityLineItem oli1:oliLst){
                                        if(oli1.PlanID__c == String.valueOf(pcount)){
                                            pcount++;
                                            respPlan.PlanID = String.valueOf(pcount);
                                        }
                                        else{
                                            respPlan.PlanID = String.valueOf(pcount);
                                        }
                                    }
                                    resClonedPlans.add(respPlan);
                                    pcount++;*/
                                    respPlan.PlanID =String.valueOf(Math.floor(Math.random()*(9999999-2500000+1))+2500000).subString(0,7);//13674
                                    resClonedPlans.add(respPlan);
                                }
                            }
                            system.debug('Line 226');                            
                            //for OSR/UW Cloned
                            //resPlanMap - updated
                            //allPlansWPD - updated
                            
                            P2EhGlobalUtil.planTypeGroupMap = new Map<String, String>();
                            P2EhGlobalUtil.planTypeGroupMapNew = new Map<String, String>();//by Geetha for 13661 on Nov 4
                            List<P2EwPlanDesignLite> newWPDL = new List<P2EwPlanDesignLite>();
                            for(P2EwPlanDesignLite wpdl : cache.allPlansMap.values()){
                                if(wpdl.GroupNumber!=null && P2EhGlobalUtil.planTypeGroupMap.get(wpdl.productType +':'+ wpdl.contractType) == null && cache.selectedOpportunity.Type=='Change'){ //last condition added for 13661
                                    P2EhGlobalUtil.planTypeGroupMap.put(wpdl.productType +':'+ wpdl.contractType, wpdl.GroupNumber);
                                }
                                //13661
                                if(wpdl.GroupNumber!=null && P2EhGlobalUtil.planTypeGroupMapNew.get(wpdl.productType) == null && cache.selectedOpportunity.Type=='Renewal'){ //wpdl.action == 'Existing'){
                                    P2EhGlobalUtil.planTypeGroupMapNew.put(wpdl.productType,wpdl.GroupNumber);
                                }
                                //Till here for 13661
                            }
                            system.debug('line 238');
                            if(!resClonedPlans.isEmpty()){
                                Boolean flag = addPlansToCache(req.CaseID, resClonedPlans);
                                system.debug(flag+'Line 241');

                                if(!flag){
                                   return new P2EwService.SF001Response('Error', errorList); 
                                }
                                if(!test.isRunningTest())
                                    insertAll();                                
                                isResClonedPlans = true;
                            }
                            
                            system.debug('allPlansWPD ::: ' + allPlansWPD);
                            system.debug('resPlanMap ::: ' + resPlanMap);
                            
                            Map<Id, String> prodPlanIdMap = new Map<Id, String>();
                            Map<Id, String> prodPlanIdMapNew= new Map<Id, String>();
                            if(!resPlanMap.isEmpty()){
                                for(String planId : cache.allPlansMap.keyset()){
                                    if(!resPlanMap.keyset().contains(planId)){
                                        system.debug('resPlanMap Line 239 ::: ' + resPlanMap.keyset().contains(planId));
                                        cache.allPlansMap.get(planId).RFPRateGenerated = false;
                                        cache.allPlansMap.get(planId).decision = 'Not - Sold';
                                        if(cache.allPlansMap.get(planId).action == 'Existing'){
                                            cache.allPlansMap.get(planId).action = 'Discontinue';
                                            cache.allPlansMap.get(planId).freezed = true; 
                                        }
                                        prodPlanIdMap.put(cache.allPlansMap.get(planId).productId, planId);
                                    }
                                    if(resPlanMap.keyset().contains(planId) && resPlanMap.get(planId).RateUpdated!=null){
                                        prodPlanIdMapNew.put(cache.allPlansMap.get(planId).productId, planId);
                                    }
                                }
                                if(prodPlanIdMap.size()>0){
                                    List<OpportunityLineItem> oliList = [Select Id, Action__c, Decision_Status__c, Product2Id, RFP_Case_Id__c, Group_Number__c From OpportunityLineItem 
                                                        Where Product2Id IN: prodPlanIdMap.keyset() and OpportunityId =: cache.selectedOpportunity.Id];
                                    if(!oliList.isEmpty()){
                                        for(OpportunityLineItem oli : oliList){
                                            oli.Decision_Status__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).decision;
                                            oli.Action__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).action;
                                            oli.Group_Number__c = cache.allPlansMap.get(prodPlanIdMap.get(oli.Product2Id)).groupNumber;
                                            oli.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                                        }
                                        update oliList;
                                    }
                                }
                                if(prodPlanIdMapNew.size()>0){
                                   List<OpportunityLineItem> oliList1 = [Select Id, Action__c, Decision_Status__c,IsRateUpdated__c, Product2Id, RFP_Case_Id__c, Group_Number__c From OpportunityLineItem 
                                                        Where Product2Id IN: prodPlanIdMapNew.keyset() and OpportunityId =: cache.selectedOpportunity.Id];
                                    String ProdPlanId;                  
                                    if(!oliList1.isEmpty()){
                                        for(OpportunityLineItem oli1 : oliList1){ 
                                            ProdPlanId = prodPlanIdMapNew.get(oli1.Product2Id);
                                            oli1.IsRateUpdated__c = resPlanMap.get(ProdPlanId).RateUpdated;
                                        }
                                        update oliList1;
                                    }
                                }
                                for(String planId : resPlanMap.keyset()){
                                    if(cache.allPlansMap.keyset().contains(planId) && resPlanMap.get(planId)!=null){
                                        if(resPlanMap.get(planId).ContractType != 'ASC (Self funded)' && resPlanMap.get(planId).ContractType != 'ASC with Stop Loss'){  //Added for 2-way Communication
                                            cache.allPlansMap.get(planId).ApproveCommission=resPlanMap.get(planId).ApproveCommission;
                                            cache.allPlansMap.get(planId).ApproveCommissionType=resPlanMap.get(planId).ApproveCommissionType;
                                        }//Till here        
                                        
                                        if(resPlanMap.get(planId).UWQuestionnaire!=null){
                                            allPlansWPD.get(planId).UWQuestionnaire__c = JSON.serialize(resPlanMap.get(planId).UWQuestionnaire);
                                            
                                        }
                                        if(resPlanMap.get(planId).ImplementationNotes !=null){
                                            allPlansWPD.get(planId).Implementation_Notes__c = EncodingUtil.base64Decode(resPlanMap.get(planId).ImplementationNotes).toString();
                                            
                                        }
                                        if(resPlanMap.get(planId).BenefitNotes !=null){
                                            allPlansWPD.get(planId).Benefit_Notes__c= EncodingUtil.base64Decode(resPlanMap.get(planId).BenefitNotes).toString();
                                            
                                        }
                                        if(resPlanMap.get(planId).ClonedPlanID!=null && resPlanMap.get(planId).ClonedPlanID!=''){
                                            cache.allPlansMap.get(planId).clonedPlanId = resPlanMap.get(planId).ClonedPlanID;
                                        }
                                        cache.allPlansMap.get(planId).OsrPlanId = resPlanMap.get(planId).OSRPlanId;
                                        allPlansWPD.get(planId).OSR_Plan_Id__c = resPlanMap.get(planId).OSRPlanId;//13674
                                        //cache.allPlansMap.get(planId).isOSRPlan = resPlanMap.get(planId).OSRPlan;//13674
                                        //allPlansWPD.get(planId).Is_OSR_Plan__c = resPlanMap.get(planId).OSRPlan;//13674
                                        cache.allPlansMap.get(planId).isOSRPlan = resPlanMap.get(planId).OSRPlanSFDC;//PC-15155
                                        allPlansWPD.get(planId).Is_OSR_Plan__c = resPlanMap.get(planId).OSRPlanSFDC;//PC-15155
                                        /*****HCL::START PRA-21 - Update Pricing and DeltaRetainedSavings recieved from PEGA*****/
                                        System.debug(LoggingLevel.ERROR, 'J****Plan Id: ' + planId);
                                        System.debug(LoggingLevel.ERROR, 'J****Pricing: ' + resPlanMap.get(planId).Pricing);
                                        System.debug(LoggingLevel.ERROR, 'J****Delta Retained Savings: ' + resPlanMap.get(planId).DeltaRetainedSavings);
                                        
                                        if(resPlanMap.get(planId).Pricing=='Standard' && String.isBlank(resPlanMap.get(planId).DeltaRetainedSavings)){
                                            errorList.add(new P2EwService.ServiceError('SF001-19','Required Fields Missing for Plan - DeltaRetainedSavings'));
                                            return new P2EwService.SF001Response('Error', errorList);
                                        }
                                        allPlansWPD.get(planId).Pricing__c = resPlanMap.get(planId).Pricing;
                                        
                                        //Added for 2-way communication 
                                        System.debug('SmileWay****: ' + resPlanMap.get(planId).SmileWay);
                                        allPlansWPD.get(planId).Smile_way__c = resPlanMap.get(planId).SmileWay;         //UC#4
                                        cache.allPlansMap.get(planId).isSmileWay = resPlanMap.get(planId).SmileWay;
                                        
                                        System.debug('IsOfferedPlan ****: ' + resPlanMap.get(planId).IsOfferedPlan);
                                        allPlansWPD.get(planId).Offered__c = resPlanMap.get(planId).IsOfferedPlan;      //UC#6
                                        
                                        cache.allPlansMap.get(planId).isOffered = resPlanMap.get(planId).IsOfferedPlan; //UC#6
                                        //Till here for 2-way communication
                                        
                                        if(String.isNotBlank(resPlanMap.get(planId).DeltaRetainedSavings)){
                                            allPlansWPD.get(planId).DeltaRetainedSavings__c= Decimal.valueOf(resPlanMap.get(planId).DeltaRetainedSavings);
                                        }
                                        /****HCL::END****/  
                                    }
                                    //prodlist.add(allPlansWPD.get(planId).product);
                                }
                                system.debug('allPlansWPD'+allPlansWPD);
                                for(P2EwPlanDesignLite wpdl : cache.allPlansMap.values()){
                                    allPlanPId.put(wpdl.PlanId, wpdl.ProductId);
                                }
                                
                                //generic for all Plans [Existing & OSR/UW Cloned]
                                rateCompareMap = storeRate();
                                if(errorList.size()>0){
                                     system.debug('removePlans'+removePlans);
                                     for(String planStr: removePlans){      
                                        cache.allPlansMap.remove(planStr);      
                                    }
                                           
                                    cache.allPlanIds.clear();       
                                    cache.allPlanIds.addAll(cache.allPlansMap.keySet());        
                                    savecache();
                                    system.debug('cache.allPlansMap'+cache.allPlansMap);        
                                    system.debug(cache.allPlansMap.keySet() + 'Line 379' + cache.allPlanIds);       
                                    List<opportunitylineitem> OLItoDelete = [select id from opportunitylineitem where opportunityid =: cache.selectedopportunity.id and PlanID__c in: removePlans]; 
                                    system.debug('OLItoDelete'+OLItoDelete);    
                                    Delete OLItoDelete;
                                    return new P2EwService.SF001Response('Error', errorList);
                                }
                            }
                        }
                        
                        
                        /*if(UWNotes!=null){
                            cache.createdQuote.UW_Notes__c = EncodingUtil.base64Decode(UWNotes).toString();
                        }*/ //commented for UWNotes
                        cache.createdQuote.RFP_Case_Status__c = req.CaseStatus;
                        
                        // Future Callout for auto renewal opportunity without new products come from OSR
                        Map<Id, OpportunityLineItem> mapOli = new Map<Id, OpportunityLineItem>();
                        if(cache.createdQuote.RFP_Case_Status__c == 'Resolved-Completed'){ // && !isResClonedPlans
                            Map<String, String> mapClonedPlanId = new map<String, String>();
                            //This condition will check whether the existing plan is cloned from OSR end or not. 
                            //As this is only the check we dont need all the plans cloned from osr system.
                            if(isResClonedPlans){
                                for(P2EwPlanDesignLite wpd: cache.allPlansMap.Values()){
                                    if(wpd.clonedPlanId != Null){
                                        mapClonedPlanId.put(wpd.clonedPlanId, wpd.PlanId);
                                    }
                                }
                            }
                            //Modified By Parthi - Auto Sold and Auto Impl will not happen for rerated and negotiated quote.
                            //Modified By Parthi - Even Negotiation existing plans can be auto sold for PC-12691
                            if(cache.selectedOpportunity.type == 'Renewal' && cache.wizardType != 'Re-Rate' && cache.createdQuote.Is_Rerated_Quote__c==false){  // && cache.wizardType != 'Negotiation' Last condition added by Geetha for PC-13361                           
                                Set<Id> setProdIds = new Set<Id>();
                                List<OpportunityLineItem> listOliToBeUpdated = new List<OpportunityLineItem>();
                                if(cache.selectedOpportunity.type == 'Renewal'){ // && rateCompareMap.get(wpd.planId)
                                    for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
                                        //AutoSold and AutoIMPl will not happen for Re-Implementation Re-Rate.
                                        if(wpd.action == 'Existing' && !mapClonedPlanId.containsKey(wpd.PlanId)){
                                            wpd.decision = 'Sold';
                                            isAutoIMPL = true;
                                            setProdIds.add(wpd.productId);
                                        }
                                        if(wpd.decision != 'Decision Pending') {
                                            isDecisionSold = true;
                                        }
                                        /*if(wpd.action == 'Discontinue'){
                                            wpd.action = 'Existing';
                                            wpd.freezed = false;
                                        }*/                                       
                                    }
                                    system.debug('check decision status'+isDecisionSold);
                                    if(isDecisionSold) {        
                                        cache.CreatedQuote.Status= 'Completed'; 
                                    }                                      
                                }
                                
                                /*if(cache.selectedOpportunity.type == 'Renewal'){
                                    cache.CreatedQuote.Status= 'Completed';
                                }*/
                                system.debug(cache.selectedOpportunity.Id+'Line 274');
                                for(OpportunityLineItem OLI: [Select Id, Action__c, Decision_Status__c, Product2Id, RFP_Case_Id__c, Group_Number__c From OpportunityLineItem 
                                        Where Product2Id IN: setProdIds and OpportunityId =: cache.selectedOpportunity.Id and Parent_Impl_Case_Id__C = null and IsReRate__c = False]){
                                    mapOli.put(OLI.Product2Id, OLI);
                                }
                                system.debug('Line 282' + cache.allPlansMap.values());
                                for(P2EwPlanDesignLite wpd: cache.allPlansMap.values()){
                                    OpportunityLineItem updateOLI = mapOli.get(wpd.ProductId);
                                    system.debug(wpd+'Line 280');
                                    if(updateOLI != Null){
                                        updateOLI.Action__c = wpd.Action;
                                        updateOLI.Decision_Status__c = wpd.decision;
                                        updateOLI.RFP_Case_Id__c = cache.createdQuote.RFP_Case_Id__c;
                                        if(wpd.groupNumber!=null){
                                            updateOLI.Group_Number__c = wpd.groupNumber;
                                        }
                                        listOliToBeUpdated.add(updateOLI);
                                    }                         
                                }
                                update listOliToBeUpdated;
                                
                                System.debug('IS AUTO IMPL**' + isAutoIMPL);
                                if(isAutoIMPL){
                                    RecordType implementationRecordType;
                                    try{
                                        implementationRecordType = [select id from RecordType where sObjectType = 'Case' and name ='Implementation'];
                                    }catch(Exception e){
                                        System.debug(e.getMessage());
                                        Database.rollback(sp);
                                        P2EhGlobalUtil.ServiceErrorCde = 'SF001-22';
                                        P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                                        throw new P2EException('P2EhRFPResponseService - sf001','', e);
                                    }
                                    Case caseInsert = new Case();
                                    caseInsert.Subject = 'IMPL Case :::';
                                    caseInsert.AccountId = cache.selectedAccount.Id;
                                    caseInsert.Related_Opportunity__c = cache.selectedOpportunity.Id;
                                    if(implementationRecordType != null){
                                        caseInsert.recordTypeId = implementationRecordType.Id;
                                    }
                                    insert caseInsert;
                                }
                            }
                        }
                        
                        cache.frameRenewalLink();
                        try{
                            if(!Test.isRunningTest()){
                                //P2EhGlobalUtil.comPlans = false;
                                //P2EhGlobalUtil.comOlis = false;
                                //insertAll();
                                update cache.createdQuote;
                                update cache.createdCase; //Added by parthi 19/02/2016
                                update allPlansWPD.values();
                                //Commented for PC-16759
                                /*if(isOpportunityUpdate){    //Added for Lives change
                                    update cache.selectedOpportunity; 
                                }*///Commented for PC-16759
                                System.debug('Updated selectedOpportunity**' + cache.selectedOpportunity);
                                //Till here for Lives Change
                                saveCache();
                            }
                        }catch(P2EException e){
                            e.addSource('P2EhRFPResponseService- sf001()');
                            //e.logException();
                            Database.rollback(sp);
                            P2EhGlobalUtil.ServiceErrorCde = 'SF001-000';
                            P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                            throw e;
                        }
                        
                        if(cache.selectedOpportunity.type == 'Renewal' && isAutoIMPL) { //cache.selectedOpportunity.AutoRenewal__c == True) || 
                            futureAuotoIMPLCallout(cache.CreatedQuote.Id, mapOli.keyset());
                            //Update Stage automatically to Renewal Decision Won, when auto sold products.           
                            //Modified on 13-09-2016 by Parthiban P                  
                            //cache.selectedopportunity.stagename = 'Renewal Decision Won';
                            cache.selectedopportunity.stagename = Label.Sales_Stages_Won;// Changed for Sales Stage - Sujit  
                            cache.selectedopportunity.Workflow_Stage__c = Label.Sales_Stages_Renewal_Decision_Won;// Changed for Sales Stage - Sujit
                            update cache.selectedOpportunity;                        
                        }
                    }
                }
                 
                //Send Email - No need to send this email as handled in workflow
              /*  try{
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(opp.OwnerID);
                    mail.setPlainTextBody('Hi, \n \nUW RFP Case Status for your Quote:'+ quot.Name + ' w.r.t the Opportunity:' + opp.Name + ' has been changed to ' + req.CaseStatus + '.\n\n Thanks');
                    mail.setSubject('RFP UW Case Status Change Notification');
                    mail.setSenderDisplayName('Salesforce DD Sandbox Alert');
                    mail.setSaveAsActivity(false);
                    Messaging.SendEmailResult[] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
                }catch(Exception e){
                    system.debug('Mail Notification failed');
                    system.debug(e.getMessage());
                    Database.rollback(sp);
                    P2EhGlobalUtil.ServiceErrorCde = 'SF001-00';
                    P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
                    throw new P2EException('P2EhRFPResponseService - sf001','', e);
                } */
                return (new P2EwService.SF001Response('OK'));
            }
        }catch(Exception e){
            system.debug(LoggingLevel.Error, 'Error ::: ' + e.getMessage() + ' at ' + e.getLineNumber());
            P2EhGlobalUtil.ServiceErrorCde = 'SF001-000';
            P2EhGlobalUtil.ServiceErrorMsg = 'Service Failed. Contact Administrator.';
            throw new P2EException('P2EhRFPResponseService - sf001','', e);
        }
   
    }
    
    /**
* SF001 Response Parsing
* @description Method To Stror the rates for the SF001 Response
*/  
    private Map<String, Boolean> storeRate(){
        Set<String> plnIds;
        Set<Id> prodIds;
        
        if(req == null){
            errorList.add(new P2EwService.ServiceError('SF001-00','No Request Received'));
            return null;
        }
        
        plnIds = new Set<String>(cache.allPlanIds);
        prodIds = new Set<Id>(allPlanPId.values());
        
        //Pre-process
        /*prodIds = new Set<Id>();
        for(OpportunityLineItem oli : [select id, product2Id from OpportunityLineItem where opportunityId =: cache.selectedOpportunity.Id and product2.PlanID__c in: plnIds]){
            prodIds.add(oli.product2Id);
        }*/
        
        //Product Segment
        Map<Id, Set<Id>> prodSegMap = new Map<Id, Set<Id>>();
        Set<Id> segIds;
        for(ProdSegment__c prodSeg : [select id, segmentation__c, Product__c from ProdSegment__c where Product__c in: prodIds]){
            if(prodSegMap.get(prodSeg.Product__c)!=null){
                segIds = prodSegMap.get(prodSeg.Product__c);
            }else{
                segIds = new Set<Id>();
            }
            segIds.add(prodSeg.segmentation__c);
            prodSegMap.put(prodSeg.Product__c, segIds);
        }
        //Added by Parthiban for not setting to inactive state if rate not came for products
        system.debug(req.proposal.plans+'Line 526'+req.proposal.plans);
        Set<String> SF001ProdIds = new Set<String>();
        for(P2EwPegaService.QQPlans plans: req.proposal.plans){
            if(plans.Product2ID != Null && plans.Product2ID != ''){
                SF001ProdIds.add(plans.Product2ID);
            }
        }
        system.debug(SF001ProdIds+'Line 534');
        //Product 
        
        List<RateSheet__c> actRSList = [select id, Type__c from RateSheet__c where Product2__c in:SF001ProdIds and 
                            ((Type__c = 'Activate' and (Response_Quote__c =: cache.createdQuote.Id or Request_Quote__c =: cache.createdQuote.Id)) or (Type__c = 'New' and Request_Quote__c =: cache.createdQuote.Id))];
        //Replaced SF001ProdIds from prodIds 
        for(RateSheet__c rs : actRSList){
            if(rs.Type__c == 'Activate'){
                rs.Type__c = 'InActivate';
            }
        }
        if(SF001ProdIds.size() > 0){
            update actRSList;
        }
        Map<Id, String> planTierMap = new Map<Id, String>();
        for(Rates__c rate : [select id, TierType__c, TierSubtype__c, RateSheet__r.Product2__c, RateSheet__r.Type__c, AdminAnalysis__c, GRRate1__c, GRRate2__c, GRRate3__c 
                from Rates__c where RateSheet__c in: actRSList and GRRate1__c = null and GRRate2__c = null and GRRate3__c = null and AdminAnalysis__c = null 
                order by CreatedDate DESC]){
            if(planTierMap.get(rate.RateSheet__r.Product2__c)==null && rate.TierType__c!=null && rate.TierSubtype__c!=null){
                planTierMap.put(rate.RateSheet__r.Product2__c, rate.TierType__c + ':' + rate.TierSubtype__c);
            }
        }
        
        Map<String,Tier_Codes__c> TierCodeMap = Tier_Codes__c.getAll();
        Map<String,Tier_Setup__c> TierSetupMap = Tier_Setup__c.getAll();
        
        plnIds = new Set<String>();
        
        List<P2EwWizRateSheets> wrsList; //= new List<P2EwWizRateSheets>();
        //  List<Rates__c> tierRatesList;
        List<Rates__c> adminRatesList;
        List<RateSheet__c> ASCFeeBreakdownList;
        //  List<Rates__c> generateRatesList;
        List<Span__c> spanRatesList;
        List<P2EwWizRateSheets> wizRateSheets = new List<P2EwWizRateSheets>();
        Map<Span__c, List<Rates__c>> spansMap = new Map<Span__c, List<Rates__c>>();
        
        wrsList = new List<P2EwWizRateSheets>();
        for(P2EwPegaService.QQPlans qqPlan : req.Proposal.Plans){
            plnIds.add(qqPlan.PlanID);
            if(qqPlan.RateSheets == null){
                errorList.add(new P2EwService.ServiceError('SF001-101','No RateSheets received in Request for PlanId: '+ qqPlan.PlanID));
                return null;
            }else if(qqPlan.RateSheets.isEmpty()){
                errorList.add(new P2EwService.ServiceError('SF001-101','No RateSheets received in Request for PlanId: '+ qqPlan.PlanID));
                return null;
            }
            else if(qqPlan.RateSheets.size() == 0){
                errorList.add(new P2EwService.ServiceError('SF001-101','No RateSheets received in Request for PlanId: '+ qqPlan.PlanID));
                return null;
            }
            for(P2EwPegaService.QQRateSheets qqRateSheet : qqPlan.RateSheets){
                //  generateRatesList = new List<Rates__c>();
               // tierRatesList = new List<Rates__c>();
                adminRatesList = new List<Rates__c>();
                spanRatesList = new List<Span__c>();
                 // Added new logic to implement the new Json Ratesheet Structure    
                // Commented for new Json Ratesheet structure

               /* if(qqRS.originalRates == null && qqRS.adminRates == null){
                    errorList.add(new P2EwService.ServiceError('SF001-101','No Rates received for PlanId: '+ qqPlan.PlanID));
                    return null;
                }*/ 
                /*if(qqPlan.ContractType!='ASC (Self funded)' && (qqRS.originalRates==null || (qqRS.originalRates!=null && qqRS.originalRates.isEmpty()))){
                    errorList.add(new P2EwService.ServiceError('SF001-101','No Original Rates received for Plan: '+ qqPlan.PlanName));
                    return null;
                }*/
                 
                 //Need to check and Change ContractType
                if(qqPlan.ContractType=='ASC (Self funded)' && (qqRateSheet.AdminRates==null || (qqRateSheet.AdminRates!=null && qqRateSheet.AdminRates.isEmpty()))){
                    errorList.add(new P2EwService.ServiceError('SF001-101','No Admin Rates received for Plan: '+ qqPlan.PlanName));
                    return null;
                }
                /*if(qqRS.AdminRateType == null || qqRS.AdminRateType == ''){
                    errorList.add(new P2EwService.ServiceError('SF001-101','Required fields missing. AdminRateType is missing in the request.'));
                    return null;
                }*/
                /*
                if(resPlanRSMap.get(qqPlan.PlanID)!=null){
                    qqRsList = resPlanRSMap.get(qqPlan.PlanID);
                }else{
                    qqRsList = new List<P2EwPegaService.QQRateSheets>();
                }
                qqRsList.add(qqRs);
                resPlanRSMap.put(qqPlan.PlanID, qqRsList);
                */
                
                P2EwWizRateSheets wizRateSheet = new P2EwWizRateSheets();
                RateSheet__c rs = new RateSheet__c();
                String adminType;
                if(qqRateSheet.AdminRateType == '%of Claims'){ // Need to check
                    rs.AdminRateType__c = '% of Claims';
                }else {
                    rs.AdminRateType__c = qqRateSheet.AdminRateType;
                }
                adminType = qqRateSheet.AdminRateType;  
                rs.Applied_Networks__c = qqRateSheet.AppliedNetworks;               
                rs.Contributions_Unit_of_Measure__c = qqRateSheet.ContribePercentOrDollar;
                if(rs.Contributions_Unit_of_Measure__c == '%') {
                    rs.Employer_Pays_Dependent_Actual_Value_per__c = qqRateSheet.CurEmployerContriForDependent;
                    rs.Employer_Pays_Employee_Actual_Value_perc__c  = qqRateSheet.CurEmployerContriForEmployee;
                } else if(rs.Contributions_Unit_of_Measure__c == '$') {                    
                    rs.Employer_Pays_Dependent_Actual_Value_dol__c = qqRateSheet.CurEmployerContriForDependent;
                    rs.Employer_Pays_Employee_Actual_Value_doll__c = qqRateSheet.CurEmployerContriForEmployee;           
                }              
                rs.Customer_Shared_Savings_Percentage__c = String.isBlank(qqRateSheet.CustomerSharedSavingsPercentage)?null:Decimal.valueOf(qqRateSheet.CustomerSharedSavingsPercentage);
                rs.Custom_Date__c = (qqRateSheet.CustomDate==null || !qqRateSheet.CustomDate)?false:true;  
                rs.Delta_Dental_Retained_Savings_Percentage__c = String.isBlank(qqRateSheet.DeltaRetainedSavings)?null:Decimal.valueOf(qqRateSheet.DeltaRetainedSavings);
                rs.Equalized_Deposit_Flat_Rate_Charge__c = qqRateSheet.EqualizedDepositFlatRateCharge;  
                rs.InitialPrefundAmount__c = qqRateSheet.InitialPrefundAmount != null ? String.valueOf(qqRateSheet.InitialPrefundAmount) : null;                
                rs.MonthlyDeposit__c = qqRateSheet.MonthlyDeposit;                       
                rs.Percent_of_Claims__c = qqRateSheet.PercentageofClaims;
                rs.PEPM_Admin_Fee__c = qqRateSheet.PEPMAdminFee;
                rs.PremiumHoliday__c = qqRateSheet.PremiumHoliday;           
                rs.ProposedSubsidyChange__c = Integer.valueOf(qqRateSheet.ProposedSubsidyChange);
                rs.ProposedChangeTotalRates__c = Integer.valueOf(qqRateSheet.ProposedChangeTotalRates);
                rs.ProposedMaxLiabilityChange__c = Integer.valueOf(qqRateSheet.ProposedMaxLiabilityChange);
                rs.ProposedRenewalChange__c = qqRateSheet.ProposedRenewalChange;                            
                rs.RateType__c = qqRateSheet.RateType;
                rs.RateMultiplier1__c = qqRateSheet.RateMultiplier1;
                rs.RateMultiplier2__c = qqRateSheet.RateMultiplier2;                          
                rs.RateMultiplier3__c = qqRateSheet.RateMultiplier3;
                rs.RateMultiplier4__c = qqRateSheet.RateMultiplier4;
                rs.Rate_Type__c = qqRateSheet.RatesheetType;                                        
                rs.RequiredChangeTotalRates__c = qqRateSheet.RequiredChangeTotalRates;
                rs.RequiredMaxLiabilityChange__c = qqRateSheet.RequiredMaxLiabilityChange;
                rs.RequiredRenewalChange__c = qqRateSheet.RequiredRenewalChange;
                rs.Repricing_Basis__c = qqRateSheet.RepricingBasis;
                rs.Repricing_Level__c = qqRateSheet.RepricingLevel;
                rs.RecordTypeId= Schema.SObjectType.RateSheet__c.getRecordTypeInfosByDeveloperName().get('Post_GC').getRecordTypeId(); 
                rs.SubsidyAsOfTotalRates__c = qqRateSheet.SubsidyAsOfTotalRates;   
                rs.Standard_Pricing__c = qqRateSheet.StandardPricing;
                rs.Billing_Tier_Structure_Code__c = qqRateSheet.TierStructureCode;
                if(TierCodeMap.containsKey(qqRateSheet.TierStructureCode)){                
               //need to change
                    rs.Billing_Tier_Structure_txt__c = TierCodeMap.get(qqRateSheet.TierStructureCode).GC_Tier_Value__c;
                    
                }
                
                rs.Total_Prefund_Amount__c = String.isBlank(qqRateSheet.TotalPrefundAmount)?null:Decimal.valueOf(qqRateSheet.TotalPrefundAmount);
                rs.Total__c = Integer.valueOf(qqRateSheet.Total);                              
                rs.Stop_Loss_Corridor__c = String.isBlank(qqRateSheet.StopLossCorridor)?null:qqRateSheet.StopLossCorridor;                
                //MODIFIED BY Richard For 12062  
                if(!Test.isRunningTest())
                    rs.State__c = EncodingUtil.base64Decode(qqRateSheet.State).toString();
                rs.Response_Quote__c = String.valueOf(cache.createdQuote.Id);
                if(qqRateSheet.StartDate!=null && qqRateSheet.StartDate!=''){
                    rs.Start_Date__c = date.valueOf(qqRateSheet.StartDate.subString(0,4)+'-'+qqRateSheet.StartDate.subString(4,6)+'-'+qqRateSheet.StartDate.subString(6,8)+' 00:00:00');
                }//commented based on the heat ticket 1713284
                /*else{
                    errorList.add(new P2EwService.ServiceError('SF001-18','Required fields missing - StartDate'));
                    return null;
                }*/
                if(qqRateSheet.EndDate!=null && qqRateSheet.EndDate!=''){
                    rs.End_Date__c = date.valueOf(qqRateSheet.EndDate.subString(0,4)+'-'+qqRateSheet.EndDate.subString(4,6)+'-'+qqRateSheet.EndDate.subString(6,8)+' 00:00:00');
                }//commented based on the heat ticket 1713284
                /*else{
                    errorList.add(new P2EwService.ServiceError('SF001-19','Required fields missing - EndDate'));
                    return null;
                }*/
                rs.Type__c = 'Activate';
                if(allPlanPId!=null){
                    //rs.Product2__c = allPlanPId.get(qqPlan.PlanId);
                    rs.Product2__c = cache.allPlansMap.get(qqPlan.PlanId).productId;
                }
                
                //To Map the Admin Rates           
                if(qqRateSheet.adminRates!=null){
                    Decimal proposedPclimRT;
                    Decimal CurrentPclimRT;
                    Map<String, P2EwPegaService.QQAdminRates> respARMap = new Map<String, P2EwPegaService.QQAdminRates>();
                    for(P2EwPegaService.QQAdminRates qqAdminRates : qqRateSheet.adminRates){
                        respARMap.put(qqAdminRates.AdminAnalysis, qqAdminRates);
                    }
                    respARMap.remove('Current Admin');
                    //String adminType;
                    for(P2EwPegaService.QQAdminRates qqAdminRates : respARMap.values()){
                        Rates__c rates = new Rates__c();
                        //Need to check and Change ContractType
                        if(qqPlan.ContractType == 'ASC with Stop Loss'){
                            rates.RateType__c = 'Both';
                        }else{
                            rates.RateType__c = 'Admin';
                        }
                        /*if(qqAdminRates.PercentofClaims!=null){
                            adminType = '% of Claims';
                        }else{
                            adminType = 'PEPM';
                        }*/
                        rates.AdminType__c = adminType;
                         // Need to Test for ASC - ContractTypesAndRates - Required Admin (Custom setting)
                      //  rates.PercentofClaims__c = qqAdminRates.PercentofClaims;
                        rates.AdminAnalysis__c = qqAdminRates.AdminAnalysis;
                        rates.PEPMRate__c = qqAdminRates.PEPMRate;
                        adminRatesList.add(rates);
                       
                        if(rates.AdminAnalysis__c == 'Total Proposed'){
                            Rates__c r1 = new Rates__c();
                            r1.AdminType__c = adminType;
                            r1.PercentofClaims__c = qqAdminRates.PercentofClaims;
                            r1.AdminAnalysis__c = 'Current Fee';
                            r1.PEPMRate__c = qqAdminRates.PEPMRate;
                            adminRatesList.add(r1);
                        }
                        if(rates.AdminAnalysis__c == 'Net Renewal Fee'){
                            Rates__c r1 = new Rates__c();
                            r1.AdminType__c = adminType;
                            r1.PercentofClaims__c = qqAdminRates.PercentofClaims;
                            r1.AdminAnalysis__c = 'Renewal Fee';
                            r1.PEPMRate__c = qqAdminRates.PEPMRate;
                            adminRatesList.add(r1);
                        }
                        if(rates.AdminAnalysis__c == 'proposed'){
                            Rates__c r1 = new Rates__c();
                            r1.AdminType__c = adminType;
                            r1.PercentofClaims__c = qqAdminRates.PercentofClaims;
                            r1.AdminAnalysis__c = 'Proposed-Net';
                            r1.PEPMRate__c = qqAdminRates.PEPMRate;
                            adminRatesList.add(r1);
                        }
                         if(rates.AdminAnalysis__c == 'Proposed Admin'){
                            Rates__c r1 = new Rates__c();
                            r1.AdminType__c = adminType;
                            r1.PercentofClaims__c = qqAdminRates.PercentofClaims;
                            r1.AdminAnalysis__c = 'Current Admin';
                            r1.PEPMRate__c = qqAdminRates.PEPMRate;
                            adminRatesList.add(r1);
                        }
                        
                        if(cache.allPlansMap.get(qqPlan.planId)!=null){
                            cache.allPlansMap.get(qqPlan.planId).RFPRateGenerated = true;
                        }
                    }
                }
                 //To Map the ASCFeeBreakdown Rates
                if(qqRateSheet.ASCFeeBreakdown!=null){                                 
                    P2EhWizardUtil.storeASCFeeBreakdown(rs, qqRateSheet.ASCFeeBreakdown);                                      
                }
                
                //ProdSegments
                List<ProdSegment__c> prodSegsList = new List<ProdSegment__c>();
                if(qqRateSheet.Segments != null && qqRateSheet.Segments.size() > 0){
                    for(P2EwPegaService.QQSegments Segments : qqRateSheet.Segments){
                        if(Segments.SegmentID!=null && Segments.SegmentID!='' && cache.allPlansMap.get(qqPlan.planId)!=null){
                            ProdSegment__c prodSegm = new ProdSegment__c();
                            prodSegm.Product__c = cache.allPlansMap.get(qqPlan.planId).productId;
                            prodSegm.Segmentation__c = Segments.SegmentName;    // Updated to Segment name - Need to check                    
                            prodSegsList.add(prodSegm);
                        }
                    }
                }
                //To map the Spans and Rates
                list<Span__c> spanListInsert = new list<Span__c>();
                list<P2EwWizSpans> wizSpanList = new  list<P2EwWizSpans>();
                if(qqRateSheet.Spans != null) {                   
                    for(P2EwPegaService.QQSpanRates qqSpan : qqRateSheet.Spans) {
                        P2EwWizSpans wizSpan = new P2EwWizSpans();
                        Span__c span = new Span__c();
                        List<Rates__c> ratesList = new List<Rates__c> ();

                        span.Rate_Multiplier__c = qqSpan.RateMultiplier;
                        //Added to set default value for below fields - Start
                        span.Claim_Type__c = 'Dental';
                        span.Unit_Type__c = 'Per Contract';
                        //Added to set default value for below fields - End
                        if(qqSpan.BillingSpanStartDate != null && qqSpan.BillingSpanStartDate != ''){
                        span.Billing_Span_Start_Date__c= date.valueOf(qqSpan.BillingSpanStartDate.subString(0,4)+'-'+qqSpan.BillingSpanStartDate.subString(4,6)+'-'+qqSpan.BillingSpanStartDate.subString(6,8)+' 00:00:00');
                        }
                        if(qqSpan.BillingSpanEndDate != null && qqSpan.BillingSpanEndDate != '') {
                        span.Billing_Span_End_Date__c = date.valueOf(qqSpan.BillingSpanEndDate.subString(0,4)+'-'+qqSpan.BillingSpanEndDate.subString(4,6)+'-'+qqSpan.BillingSpanEndDate.subString(6,8)+' 00:00:00');
                        }

                        if(qqSpan.AdminComponents != null) {
                              span = (Span__c) P2EhWizardUtil.configSpan(span, qqSpan.AdminComponents);
                        }
                            
                        //spanRatesList.add(span);
                    system.debug('**** qqSpan.Rates **** '+qqSpan.Rates);
                        if(qqSpan.Rates != null) {
                            for(P2EwPegaService.QQRates qqRates : qqSpan.Rates) {
                                Rates__c rates = new Rates__c();
                                //Need to check and Change ContractType 
                                if(qqPlan.ContractType == 'ASC with Stop Loss') { 
                                    rates.RateType__c = 'Both';
                                } else {
                                    rates.RateType__c = 'Tier';
                                }

                                if(allPlanPId != null && allPlanPId.get(qqPlan.PlanId) != null 
                                        && planTierMap!=null && planTierMap.get(allPlanPId.get(qqPlan.PlanId)) != null 
                                        && planTierMap.get(allPlanPId.get(qqPlan.PlanId)).contains(':')) {
                                    rates.TierType__c = planTierMap.get(allPlanPId.get(qqPlan.PlanId)).split(':')[0];
                                    rates.TierSubtype__c = planTierMap.get(allPlanPId.get(qqPlan.PlanId)).split(':')[1];
                                }
                                rates.Tier_Structure_Code__c = qqRateSheet.TierStructureCode;
                                //UW Opt-ph 1: map tier type and sub type from tiercode.
                                if(rates.TierType__c==null || rates.TierSubtype__c ==null) {
                                    if(rates.Tier_Structure_Code__c != '' && rates.Tier_Structure_Code__c != null) {
                                        Tier_codes__c tierCodeObj = Tier_codes__c.getValues(rates.Tier_Structure_Code__c);
                                        system.debug('*** '+tierCodeObj);
                                        if(tierCodeObj != null) {
                                            rates.TierSubtype__c = tierCodeObj.Tier_Type__c;
                                            rates.TierType__c = tierCodeObj.Type__c;
                                        }
                                    }
                                }
                                 //To map the Rates under the Span
                                    ratesList.add(P2EhWizardUtil.configRates(rates, qqRates, TierSetupMap, qqPlan.ProductDescription));
                        system.debug('**** ratesList 1**** '+ratesList);
                                if(cache.allPlansMap.get(qqPlan.planId)!=null){
                                    cache.allPlansMap.get(qqPlan.planId).RFPRateGenerated = true;
                                }
                            }
                        }
                        
                        wizSpan.span =span;
                        wizSpan.spanRates = ratesList;
                        wizSpanList.add(wizSpan);
                        ///ystem.debug('**** ratesList 2**** '+ratesList);
                        //spansMap.put(span, ratesList);
                        //system.debug('**** spansMap 2**** '+spansMap);
                    }
                }
               
                wizRateSheet.rateSheet = rs;
               // wizRateSheet.originalRates = tierRatesList;
                wizRateSheet.adminRates = adminRatesList;
                wizRateSheet.prodSegments = prodSegsList;
                wizRateSheet.SpanRates = wizSpanList;
               // wizRateSheet.generateRates = generateRatesList;
                wrsList.add(wizRateSheet);
            }
            system.debug('Line 760'+osrPlanIds);
            system.debug('Line 761' + qqPlan.planId);
            system.debug('Line 762'+ wrsList);
            system.debug('Line 763'+ osrPlanIds.contains(qqPlan.planId));
            if(osrPlanIds.contains(qqPlan.planId) && wrsList!=null){            
                P2EwWizRateSheets wizRateSheet = wrsList[0];
                P2EwWizRateSheets wrsNew = new P2EwWizRateSheets();
                wrsNew.ratesheet = new RateSheet__c(); //wizRateSheet.ratesheet.clone();
                wrsNew.rateSheet.Type__c = 'New';
                wrsNew.rateSheet.Request_Quote__c = String.valueOf(cache.createdQuote.Id);
                wrsNew.rateSheet.product2__c=cache.allPlansMap.get(qqPlan.PlanId).productId;
               // wrsNew.originalRates = wizRateSheet.originalRates.deepClone();
                wrsNew.adminRates = wizRateSheet.adminRates.deepClone();
                wrsNew.TierType = wizRateSheet.TierType;
                wrsNew.TierSubType = wizRateSheet.TierSubType;
                wrsNew.AdminType = wizRateSheet.AdminType;
                wrsList.add(wrsNew);
            }
        }
        List<RateSheet__c> rsList = new List<RateSheet__c>();
        for(P2EwWizRateSheets wizRateSheet : wrsList){
            rsList.add(wizRateSheet.rateSheet);
         }
        insert rsList;
        
        system.debug('Line 791' + rsList);        
        List<Rates__c> ratesFinalList = new List<Rates__c>();
        List<Span__c> SpanInsertList = new List<Span__c>();
        for(P2EwWizRateSheets wrs : wrsList){
            for(Rates__c rs : wrs.adminRates){
                rs.RateSheet__c = wrs.rateSheet.Id;
                ratesFinalList.add(rs);
            }
            
            for(P2EwWizSpans sp : wrs.SpanRates){
                if(sp.span != null) {
                    sp.span.Rate_Sheet_Span__c = wrs.rateSheet.Id;
                    SpanInsertList.add(sp.span);
                }
            }

        }
        
        insert SpanInsertList;
        //Span related Rates insert list with Span ID
        for(P2EwWizRateSheets wrs : wrsList){
            for(P2EwWizSpans sp : wrs.SpanRates){
                if(sp.span != null && sp.spanRates != null && sp.spanRates.size() > 0) {
                    for(Rates__c rs : sp.spanRates){
                        rs.Span__c = sp.span.Id;
                        ratesFinalList.add(rs);
                    }
                }
            }
        }
        insert ratesFinalList;     
        return null;
    }
    
       
    //Add plan to cache
    private Boolean addPlansToCache(String caseId, List<P2EwPegaService.QQPlans> respPlans){
        Id grrec = P2EhUtility.getRecordTypeId('TTPLs__c','Grouping');
        Id rec = P2EhUtility.getRecordTypeId('TTPLs__c','Procedure Level');
        Id ttrec = P2EhUtility.getRecordTypeId('TTPLs__c','Treatment');
        Map<String, P2EwPlanDesignLite> mapPlanIdPDL = new Map<String, P2EwPlanDesignLite>();
        for(P2EwPegaService.QQPlans respPlan : respPlans){
            if(respPlan.ContractType == null || respPlan.ContractType == ''){
                errorList.add(new P2EwService.ServiceError('SF001-23','Required Fields Missing for Cloned Product - ContractType'));
                return false;
            }
            if(respPlan.PlanName == null || respPlan.PlanName == ''){
                errorList.add(new P2EwService.ServiceError('SF001-07','Required Fields Missing for Cloned Product - PlanName'));
                return false;
            }
            if(respPlan.ProductName!='DHMO'){
                if(respPlan.ProgramType == null || respPlan.ProgramType == ''){
                errorList.add(new P2EwService.ServiceError('SF001-08','Required Fields Missing for Cloned Product- ProgramType'));
                return false;
                }
            }
            if(respPlan.ProductName == null || respPlan.ProductName == ''){
                errorList.add(new P2EwService.ServiceError('SF001-09','Required Fields Missing for Cloned Product - ProductName'));
                return false;
            }
            if(respPlan.ProductName!='DHMO'){
                if(respPlan.OONReimbursement == null || respPlan.OONReimbursement == ''){
                errorList.add(new P2EwService.ServiceError('SF001-10','Required Fields Missing for Cloned Product - OONReimbursement'));
                return false;
                }
            }
            if(respPlan.ProductDescription == null || respPlan.ProductDescription == ''){
                errorList.add(new P2EwService.ServiceError('SF001-11','Required Fields Missing for Cloned Product - ProductDescription'));
                return false;
            }
            if(respPlan.EffectiveDate == null || respPlan.EffectiveDate == ''){
                errorList.add(new P2EwService.ServiceError('SF001-18','Required Fields Missing for Cloned Product - EffectiveDate '));
                return false;
            }
            //HCL::START Add validation for Delta Retained Savings
            if(respPlan.Pricing=='Standard' && String.isBlank(respPlan.DeltaRetainedSavings)){
                errorList.add(new P2EwService.ServiceError('SF001-19','Required Fields Missing for Cloned Product - DeltaRetainedSavings'));
                return false;
            }
            //HCL::END
                       
            P2EwWizPlanDesign newPlan = new P2EwWizPlanDesign();
            P2EwPlanDesignLite newPDL = new P2EwPlanDesignLite();
            
            //respPlan.PlanId = respPlan.OSRPlanID;
            
            newPDL.productType = respPlan.ProductName;
            newPDL.contractType = respPlan.ContractType;
            newPDL.planName = respPlan.PlanName;
            newPDL.planId = respPlan.PlanID; //String.valueOf(count+1); //respPlan.OSRPlanID;
            removePlans.add(respPlan.PlanId);       
            system.debug(removePlans + 'LIne 1306');
            newPDL.status = 'Completed';
            newPDL.freezed = false;
            newPDL.action = 'New';
            newPDL.decision = 'Decision Pending';
            //newPDL.isOffered = false;
            newPDL.isOffered = respPlan.IsOfferedPlan;  //Added for 2-way communication UC#6 and commented the above line
            newPDL.isSmileWay = respPlan.SmileWay;    //Added for 2-way communication UC#4
            newPDL.hasNonOfferedApproval = false;
            newPDL.isParent = false;
            newPDL.firstPlan = false;
            newPDL.isClaimsExperience = false;
            newPDL.RFPRateGenerated = false;
            newPDL.isCurrentPlan = false;
            newPDL.isNegotiated = false;
            newPDL.selected = false;
            newPDL.OsrPlanId = respPlan.OSRPlanID;
            //newPDL.IsOSRPlan = respPlan.OSRPlan;//13674
            newPDL.IsOSRPlan = respPlan.OSRPlanSFDC; //PC-15155
            if(respPlan.clonedPlanId != null && resPlanMap.get(respPlan.clonedPlanId)!=null){
                if(resPlanMap.get(respPlan.clonedPlanId).ProductName == respPlan.ProductName && ((resPlanMap.get(respPlan.clonedPlanId).ContractType == respPlan.ContractType && cache.selectedOpportunity.Type=='Change') || cache.selectedOpportunity.Type=='Renewal')){//condition modified for 13661
                    newPDL.GroupNumber = cache.allPlansMap.get(respPlan.clonedPlanId).GroupNumber;
                }
            }
            if(newPDL.GroupNumber==null && P2EhGlobalUtil.planTypeGroupMap!=null 
                && P2EhGlobalUtil.planTypeGroupMap.get(respPlan.ProductName+':'+respPlan.ContractType)!=null && cache.selectedOpportunity.Type=='Change'){//last condition added for 13661
                newPDL.GroupNumber = P2EhGlobalUtil.planTypeGroupMap.get(respPlan.ProductName+':'+respPlan.ContractType);
            }
            //13661
            if(newPDL.GroupNumber==null && P2EhGlobalUtil.planTypeGroupMapNew!=null 
                && P2EhGlobalUtil.planTypeGroupMapNew.get(respPlan.ProductName)!=null && cache.selectedOpportunity.Type=='Renewal'){
                newPDL.GroupNumber = P2EhGlobalUtil.planTypeGroupMapNew.get(respPlan.ProductName);
            }
            //Till here for 13661
            
            newPlan.product = new Product2();
            newPlan.product.PlanID__c = newPDL.planId;
            newPlan.product.Group_Number__c = newPDL.GroupNumber;//Added for PC-14083
            newPlan.product.Description = respPlan.ContractType;
            if(respPlan.ImplementationNotes!=null){
                newPlan.product.Implementation_Notes__c = EncodingUtil.base64Decode(respPlan.ImplementationNotes).toString();
            }
            if(respPlan.BenefitNotes!=null){
                newPlan.product.Benefit_Notes__c = EncodingUtil.base64Decode(respPlan.BenefitNotes).toString();
            }
            newPlan.product.Benefit_Notes__c = EncodingUtil.base64Decode(respPlan.BenefitNotes).toString();
            //newPlan.product.UWEditedProduct2ID__c = respPlan.UWClonedProduct2ID;
            //newPlan.product.UWEditedPlanID__c = respPlan.UWClonedPlanID;
            newPlan.product.Student_Age__c = respPlan.StudentAge;
            newPlan.product.Strategic_Information__c = respPlan.StrategicInfo;
            newPlan.product.Section_125__c = respPlan.Section125Ind;
            newPlan.product.Previous_Contribution_Comments__c = respPlan.ProposedContrComments;
            //newPlan.product.Program_Tier_1__c = respPlan.ProgramType;
            //newPlan.product.Out_of_Network_reimbursement__c = respPlan.OONReimbursement;
            if(respPlan.product!=null && respPlan.product.networks!=null && respPlan.product.networks.size()==2){
              newPlan.product.Program_Tier_1__c = 'Premier';
            }else if(respPlan.ProductName=='DHMO'){   // condition added as part of PC-16751 - Start
              newPlan.product.Program_Tier_1__c = null;
            }            
            else {
              newPlan.product.Program_Tier_1__c = 'PPO/Premier';
            } // PC-16751 - End            
            newPlan.product.Out_of_Network_reimbursement__c = 'Standard';
            newPlan.product.Delivery_Method__c = respPlan.ProductName;
            newPlan.product.Previous_Commision__c = respPlan.PreviousCommission;
            newPlan.product.Name = respPlan.PlanName;
            newPlan.product.Payment_Frequency_Comments__c = respPlan.PaymentFrequencyComments;
            newPlan.product.Payment_frequency__c = respPlan.PaymentFrequency;
            
            //Modified the below code for PC-11598 by Parthiban on 15-06-2016
            if(respPlan.NewHireEligibilityPeriod != Null){
                if(!respPlan.NewHireEligibilityPeriod.contains('days')){
                    newPlan.product.New_Hire_Eligibility_Period__c = respPlan.NewHireEligibilityPeriod;
                    newPlan.product.EligibilityInMonths__c = false;
                }else{
                    String tempDays = respPlan.NewHireEligibilityPeriod.replace(' days','');
                    newPlan.product.New_Hire_Eligibility_Period_In_Days__c = Integer.valueOf(tempDays);
                    newPlan.product.EligibilityInMonths__c = true;
                }
            }
            //--------------Upto this for PC-11598
            
            newPlan.product.Want_Match_For_Quote__c = respPlan.MatchforQuote;
            if(respPlan.IDCardType != NULL){
                newPlan.product.ID_Cards_printed__c = respPlan.IDCardType;
            }else{
                newPlan.product.ID_Cards_printed__c = false;
            }
            newPlan.product.Hybrid__c = respPlan.Hybrid;
            newPlan.product.EOC__c = respPlan.EOC;
            newPlan.product.Employer_Contribution_Employee__c = respPlan.EmployerContriSingle;
            newPlan.product.Employer_Contribution_Dependent__c = respPlan.EmployerContriDependent;
            newPlan.product.Other_Eligible_Participants_Comments__c = respPlan.EligibleParticipantsComments;
            newPlan.product.Dual_Choice__c = respPlan.Dualchoice;
            newPlan.product.Deviation__c = respPlan.Deviation;
            newPlan.product.Dependent_Age_limit__c = string.valueOf(respPlan.DependentAge);
            newPlan.product.Number_of_Current_Primary_Enrollees__c = respPlan.CurrentPrimaryEnrolee;
            newPlan.product.Employer_Contribution_Type__c = respPlan.ContribePercentOrDollar;
            newPlan.product.Employer_Contribution_Employee__c = respPlan.CurEmployerContriForEmployee;
            newPlan.product.Employer_Contribution_Dependent__c = respPlan.CurEmployerContriForDependent;
            newPlan.product.Funding_Arragements__c = respPlan.ContractType;
            newPlan.product.Previous_Contract_Turnover__c = respPlan.ContractTurnOver;
            
            System.debug('SmileWay for New Plan****: ' + respPlan.SmileWay);
            newPlan.product.Smile_way__c = respPlan.SmileWay;                 //Added for 2-Way communication UC#4
            
            System.debug('IsOfferedPlan for New Plan****: ' + respPlan.IsOfferedPlan);
            newPlan.product.Offered__c = respPlan.IsOfferedPlan;                 //Added for 2-Way communication UC#6
            
            //HCL::START Assign Zip Pricing and Delta Retained Savings for new plan added from OSR
            newPlan.product.Pricing__c = respPlan.Pricing;
            newPlan.product.DeltaRetainedSavings__c = String.isBlank(respPlan.DeltaRetainedSavings)?null:Decimal.valueOf(respPlan.DeltaRetainedSavings);
            //HCL::END
            
             //Add the effective date
            newPlan.product.Is_OSR_Plan__c = newPDL.IsOSRPlan;//13674
            newPlan.product.OSR_Plan_Id__c = newPDL.OsrPlanId;//13674
            if(respPlan.EffectiveDate != null){
                try{
                    integer year = integer.valueof(respPlan.EffectiveDate.substring(0,4));
                    integer month = integer.valueof(respPlan.EffectiveDate.substring(4,6));
                    integer day =  integer.valueOF(respPlan.EffectiveDate.substring(6,8));
                    newPlan.product.Effective_Date__c = Date.newinstance(year,month,day );
                }
                Catch (Exception e){
                    system.debug('Issue with effective date'+e.getMessage());
                }
            }
            newPlan.product = (Product2) P2EhUtility.setBooleanDefault('Product2', newPlan.product);
            
            //Networks
            CostShare__c costShare;
            TTPLs__c benefitCategory;
            TTPLs__c benefitCategoryTT;
            List<TTPLs__c> benefitCategoryList;
            if(respPlan.product != null && respPlan.product.networks != null && !respPlan.product.networks.isEmpty()){
                for(P2EwPegaService.QQNetworks respNetwork : respPlan.product.networks){
                    if(respNetwork.AnnualMaximum == null ){
                        errorList.add(new P2EwService.ServiceError('SF001-12','Required Fields Missing for Cloned Product - AnnualMaximum'));
                        return false;
                    } 
                    if(respNetwork.IndividualDeductible == null ){
                        errorList.add(new P2EwService.ServiceError('SF001-13','Required Fields Missing for Cloned Product - IndividualDeductible'));
                        return false;
                    }
                    if(respNetwork.FamilyDeductible == null ){
                        errorList.add(new P2EwService.ServiceError('SF001-14','Required Fields Missing for Cloned Product - FamilyDeductible'));
                        return false;
                    }
                    if(respNetwork.NetworkID== null ){
                        errorList.add(new P2EwService.ServiceError('SF001-15','Required Fields Missing for Cloned Product - NetworkID'));
                        return false;
                    }
                    /*if(respNetwork.OrthoDeductible== null){
                        errorList.add(new P2EwService.ServiceError('SF001-16','Required Fields Missing for Cloned Product - OrthoDeductible'));
                        return false;
                    }
                    if(respNetwork.OrthoLifetimeMax== null){
                        errorList.add(new P2EwService.ServiceError('SF001-17','Required Fields Missing for Cloned Product - OrthoLifetimeMax'));
                        return false;
                    }*/
                    if(respNetwork.ClassICoinsurance == null){
                        errorList.add(new P2EwService.ServiceError('SF001-19','Required Fields Missing for Cloned Product - ClassICoinsurance '));
                        return false;
                    }
                    if(respNetwork.ClassIICoinsurance == null){
                        errorList.add(new P2EwService.ServiceError('SF001-20','Required Fields Missing for Cloned Product - ClassIICoinsurance '));
                        return false;
                    }
                    if(respNetwork.ClassIIICoinsurance== null){
                        errorList.add(new P2EwService.ServiceError('SF001-21','Required Fields Missing for Cloned Product - ClassIIICoinsurance'));
                        return false;
                    }
                    /*if(respNetwork.OrthoCoinsurance== null){
                        errorList.add(new P2EwService.ServiceError('SF001-00','Required Fields Missing for Cloned Product - OrthoCoinsurance'));
                        return false;
                    }*/
                    costShare = new CostShare__c();
                    benefitCategoryList = new List<TTPLs__c>();
                    costShare.Waive_initial_enrollees__c = respNetwork.WaiveOnInitialEnrolees;
                    costShare.Waive_Deducible__c = respNetwork.WaiveDeductible;
                    costShare.Waive_Class_I_Maximum__c = respNetwork.WaiveClassIMaximum;
                    costShare.Waive_Class_II_Deductible__c = respNetwork.WaiveClassIIDeductible;
                    costShare.Waive_Class_I_Deductible__c = respNetwork.WaiveClassIDeductible;
                    costShare.Waiting_period_comments__c = respNetwork.WaitingPeriodComments;
                    costShare.Virgin_Ortho__c = respNetwork.VirginOrtho;
                    costShare.TMJ__c = respNetwork.TMJIndividual;
                    //costShare.Take_Over__c = respNetwork.TakeOver; //commented as for PC-11932 by Parthi
                    costShare.TMJ_Indicator__c = respNetwork.TMJIndicator;
                    costShare.TMJ_Maximum__c = respNetwork.TMJMaximum;
                    costShare.Lifetime_Per_Individual__c = respNetwork.PerIndividual;
                    // Heat 01737128
                    // OrthoWaitingPeriodMonths --> OWPNumberOfMonths
                    // Integer --> String
                    if(respNetwork.OWPNumberOfMonths == '12'){
                        costShare.Orthodontics_waiting_period__c = '12 Months Waiting Period';
                    }
                    if(respNetwork.OWPNumberOfMonths == '6'){
                        costShare.Orthodontics_waiting_period__c = '6 Months Waiting Period';
                    }else{
                        costShare.Orthodontics_waiting_period__c = respNetwork.OWPNumberOfMonths;
                    }
                    // Heat 01737128
                    // Changed: OrthoMaxTakeover --> OrthoTakeover
                    costShare.Orthodontics_Takeover__c = respNetwork.OrthoMaxTakeover;
                    // Heat 01737128
                    
                    
                    //PC-11932 Modified by Parthi
                    costShare.Deductible__c = 'Others';
                    costShare.Other_Deductible__c = '$'+Integer.valueOf(respNetwork.IndividualDeductible)+'/$'+Integer.valueOf(respNetwork.FamilyDeductible);
                    costShare.Take_Over__c = respNetwork.AnnualMaxTakeover;
                    costShare.DeductibleTakeover__c = respNetwork.DeductibleTakeOver;
                    if(respNetwork.OrthoWaitingPeriod == Null){
                        costShare.Waiting_Period_for_Ortho__c = false;
                    }else{
                        costShare.Waiting_Period_for_Ortho__c = respNetwork.OrthoWaitingPeriod;
                    }
                    if(respNetwork.Class3WaitingPeriod == Null){
                        costShare.Waiting_Periodc__c = false;
                    }else{
                        costShare.Waiting_Periodc__c = respNetwork.Class3WaitingPeriod;
                    }
                    //costShare.Number_Of_Months__c = respNetwork.Class3WaitingPeriodMonths;                     
                    //---End of PC-11932
                   
                    costShare.Orthodontics_lifetime_deductibile__c = respNetwork.OrthoDeductible;
                    costShare.Orthodontics_maximum__c = respNetwork.OrthoMax;
                    //costShare.Orthodontics_lifetime_maximum__c = respNetwork.OrthoLifetimeMax;
                    costShare.Orthodontic_Coverage__c = respNetwork.OrthodonticCoverage;
                    if(respNetwork.NetworkID == '20'){
                        costShare.Network__c = 'PPO';
                    }
                    if(respNetwork.NetworkID == '01'){
                        costShare.Network__c = 'Premier';
                    }
                    if(respNetwork.NetworkID == 'NP'){
                        costShare.Network__c = 'Non-Contracted';
                    }
                    if(respPlan.product.networks.size()==2 && costShare.Network__c == 'PPO'){
                        newPlan.product.Program_Tier_1__c = 'PPO/Premier';
                    }
                   
                    costShare.Missing_Tooth_Exclusive__c = respNetwork.MissingToothExclusion;
                    //costShare.Is_Wellness_Benefit__c = respNetwork.OrthoLifetimeMax;
                    //costShare.Current_Enrollee_Deductible__c = respNetwork.IndividualDeductible;
                    // Below field is not used in UI as well and it is hardcoded. So commenting
                    //costShare.Current_Enrollee_Deductible__c = 50;
                    costShare.Incentive_Plan_benefit_start_level__c = respNetwork.IncidentPlanBenefitStartLevel;
                    costShare.DD_4th_Quarter_Carryover__c = respNetwork.FourthQuarterCarryOver;
                    //costShare.Current_family_Deductible__c = respNetwork.FamilyDeductible;
                    // Below field is not used in UI as well and it is hardcoded. So commenting
                    //costShare.Current_family_Deductible__c = 100;
                    costShare.COB__c = String.valueOf(respNetwork.FamilyDeductible);
                    
                    //Benefit Category
                    //Set<String> groupings = new Set<String>();
                    Map<String, Integer> mapGroupingCOI = new Map<String, Integer>(); 
                    if(respNetwork.BenefitGroupers!=null){
                      for(P2EwPegaService.QQBenefitGroupers respBenifit : respNetwork.BenefitGroupers){
                          benefitCategoryTT = new TTPLs__c();
                          
                          //PC - 11073 - START
                          if(respBenifit.Name == 'Preventative'){
                              benefitCategoryTT.Choose_COI_Type__c = 'Preventive';
                          }else{
                              benefitCategoryTT.Choose_COI_Type__c = respBenifit.Name;
                          }  
                          //PC - 11073 - END
                          
                          benefitCategoryTT.CoInsurance__c = respBenifit.Coinsurance;
                          benefitCategoryTT.Grouping__c = respBenifit.ClassType;
                          benefitCategoryTT.recordTypeID = ttrec;
                          benefitCategoryList.add(benefitCategoryTT);
                          //groupings.add(respBenifit.ClassType);
                          if(!mapGroupingCOI.containsKey(respBenifit.ClassType)){
                              mapGroupingCOI.put(respBenifit.ClassType, respBenifit.Coinsurance);
                          }
                      }
                      for(P2EwPegaService.QQBenefitGroupers respBenifit : respNetwork.BenefitGroupers){
                          //Add PL
                          if(respBenifit.Benefits != Null){
                              for(P2EwPegaService.QQBenefits respPL : respBenifit.Benefits){
                                  benefitCategory = new TTPLs__c(); 
                                  //PC - 11073 - START
                                  if(respBenifit.Name == 'Preventative'){
                                      benefitCategory.Choose_COI_Type__c = 'Preventive';
                                  }else{
                                      benefitCategory.Choose_COI_Type__c = respBenifit.Name;
                                  } 
                                  benefitCategory.Grouping__c = respBenifit.ClassType;
                                  benefitCategory.recordTypeID = rec;
                                  if(respPL.Name == 'Other Preventative Services'){
                                      benefitCategory.Procedure_Level__c = 'Other Preventive Services';                                    
                                  }else{
                                      benefitCategory.Procedure_Level__c = respPL.Name;
                                  }
                                  //PC - 11073 - END
                                 
                                  benefitCategory.CoInsurance__c = respPL.Coinsurance;
                                  benefitCategoryList.add(benefitCategory);
                              }
                          }/*else{   
                              benefitCategory = new TTPLs__c();
                              benefitCategory.Grouping__c = respBenifit.ClassType;
                              benefitCategory.Choose_COI_Type__c = respBenifit.Name;                              
                              benefitCategory.CoInsurance__c = respBenifit.Coinsurance;
                              benefitCategory.recordTypeId = ttrec;
                              benefitCategoryList.add(benefitCategory);
                          } */       
                      }
                      for(String groups : mapGroupingCOI.keySet()){
                          benefitCategory = new TTPLs__c();
                          benefitCategory.Grouping__c = groups;
                          benefitCategory.recordTypeID = grrec;
                          //benefitCategory.CoInsurance__c = mapGroupingCOI.get(groups);
                          if(groups == 'D&P'){
                               benefitCategory.CoInsurance__c = respNetwork.ClassICoinsurance;
                          }
                          else if(groups == 'Basic'){
                               benefitCategory.CoInsurance__c = respNetwork.ClassIICoinsurance;
                          }
                          else if(groups == 'Major'){
                             benefitCategory.CoInsurance__c = respNetwork.ClassIIICoinsurance;
                          }
                          else if(groups == 'Orthodontics'){
                            if(respNetwork.OrthoDeductible== null){
                                errorList.add(new P2EwService.ServiceError('SF001-16','Required Fields Missing for Cloned Product - OrthoDeductible'));
                                return false;
                            }
                            if(respNetwork.OrthoMax== null){
                                errorList.add(new P2EwService.ServiceError('SF001-17','Required Fields Missing for Cloned Product - OrthoMax'));
                                return false;
                            }
                            if(respNetwork.OrthoCoinsurance == null){
                                 errorList.add(new P2EwService.ServiceError('SF001-00','Required Fields Missing for Cloned Product - OrthoCoinsurance'));
                                 return false;
                            }
                            else{
                                 benefitCategory.CoInsurance__c = respNetwork.OrthoCoinsurance;
                            }
                          }
                          else if(groups == 'TMJ'){
                              benefitCategory.CoInsurance__c = respNetwork.TMJCoinsurance;
                          }
                          benefitCategoryList.add(benefitCategory);
                      }
                    }
                    if(respNetwork.BenefitDifferential == NULL){
                        costShare.Benefit_Differential__c = false;
                    }else{
                        costShare.Benefit_Differential__c = respNetwork.BenefitDifferential;
                    }
                    //costShare.Individual_Lifetime_Max__c = respNetwork.AnnualMaximum;
                    costShare.Annual_Maximum__c= Integer.valueOf(respNetwork.AnnualMaximum); //1500
                    costShare.Accident_Rider__c = respNetwork.AccidentRider;
                    costShare = (CostShare__c) P2EhUtility.setBooleanDefault('CostShare__c', costShare);   
                    if(respNetwork.BenefitDifferential == null){
                        newPlan.Product.Benefit_Differential__c = true;
                    }else{
                        newPlan.Product.Benefit_Differential__c = respNetwork.BenefitDifferential;
                    }         
                    newPlan.costShareList.add(new P2EwWizCostShare(costShare, benefitCategoryList));
                }
            }else{
                if(respPlan.ProductName!='DHMO'){
                    errorList.add(new P2EwService.ServiceError('SF001-12','Invalid Request Received. Empty or Null Networks received'));
                    return false;
                }
            }
            
            //cache.allPlansMap.put(newPlan.product.PlanID__c, newPDL);
            mapPlanIdPDL.put(newPlan.product.PlanID__c, newPDL);
            //cache.allPlanIds.add(newPlan.product.PlanID__c);
            allPlansWPD.put(newPlan.product.PlanID__c, newPlan.product);
            resPlanMap.put(newPlan.product.PlanID__c, respPlan);
            osrPlanIds.add(newPlan.product.PlanID__c);
            
            P2EhGlobalUtil.updateOnlyRateSheets.put(newPlan.product.PlanID__c, true);
            P2EhGlobalUtil.updateCSnTTs.put(newPlan.product.PlanID__c, true);
            P2EhGlobalUtil.comAO = false;
            P2EhGlobalUtil.comQC = false;
            P2EhGlobalUtil.wPDList.add(newPlan);
        }
        cache.allPlansMap.putAll(mapPlanIdPDL);
        cache.allPlanIds.addAll(osrPlanIds);        
        return true;
    }
      
    @future (callout=true) 
    public static void futureAuotoIMPLCallout(Id qId, Set<Id> prodIds){  
        system.debug('Line 1008'+qId);
        P2EwWizCache cache=new P2EwWizCache();
        List<WizardCache__c> oldCaches = [select id, PartNumber__c, SerializedJSON__c from WizardCache__c where Quote__c =: qId Order By PartNumber__c];
        String serializedJSONStr = '';
        for(WizardCache__c oldCache : oldCaches){
            serializedJSONStr += oldCache.SerializedJSON__c;
        }
        if(serializedJSONStr!=''){
            cache = P2EwWizCache.parse(serializedJSONStr);
        }else{
            cache = null;
        }
        system.debug('Line 1020'+cache.selectedOpportunity.Id+'..cache::'+cache);
        Id oppId = cache.selectedOpportunity.Id;
        Case cas = Database.Query(P2EhUtility.getQuery('Case') + ' where Related_Opportunity__c =: oppId and Subject = \'IMPL Case :::\' Limit 1');
        
        List<OpportunityLineItem> oliList = Database.Query(P2EhUtility.getQuery('OpportunityLineItem') + ' where Product2Id in: prodIds and OpportunityId =: oppId');
        //cache.createdCase = cas;
        //ApexPages.StandardController sc = new ApexPages.StandardController(cache.selectedOpportunity.Id); 
        P2EcPlanDesignOpportunityList p = new P2EcPlanDesignOpportunityList(cache.selectedOpportunity.Id);
        p.caseInsert = cas;
        p.selProdIds = prodIds;
        p.sendLstOLI = oliList;
        p.doImplCallout();
        //P2EcPlanDesignOpportunityList p = new P2EcPlanDesignOpportunityList(oppId);
        //p.autoimplcallout(cache);
    }
    
    public P2EwService.SF001Response sf001(P2EwService.SF001Request req, List<P2EwService.ServiceError> error){
        P2EwService.SF001Response resp = new P2EwService.SF001Response();
        resp.Message = 'Error';
        resp.Errors = error;
        return resp;
    }
    
    public PageReference next(){return null;}
    public PageReference save(){return null;}
    public PageReference prev(){return null;}
    //public PageReference cancel(){return null;}
}