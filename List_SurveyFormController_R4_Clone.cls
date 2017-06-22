public class List_SurveyFormController_R4_Clone
{ 
    /* Global variables */ 
    
    private string idTemplate;
    private List<List_Input__c> lstInput{get; set;}
    private Map<Id,List<List_Input__c>> mapIDInputPicklist{get;set;}
    private Integer errorOccurance = 0;
    private List<List_Condition__c> lstCondition;
    
    public Boolean validForm{get; set;}
    public Id recordId{get; set;}
    public Id lrsId{get; set;}
    public string pageMessage{get; set;}
    public string saveType {get; set;}
    public string elementID {get; set;}
    public string newTextboxValue {get; set;}
    public string allFormElementData {get; set;}
    
    public List_Template__c objTemplate{get; set;}
    public List<List_Section__c> lstSection{get; set;}
    public Boolean hasSection{get; set;}
    
    public Map<Id,String> mapSectionShowHide{get; set;}
    public Map<Id,List<List_Input__c>> mapIDSectionInput{get;set;}
    public Map<Id, String> mapIDInputPicklistJson {get;set;}
    public Map<Id, String> mapIDInputFieldName {get;set;}
    private set<Id> setCustomValidateInput;
    
    private Map<id,map<List_Condition__c,Boolean>> mapSectionConditionEvaluted {get; set;}
    private Map<id,map<List_Condition__c,Boolean>> mapInputConditionEvaluted {get; set;}
    public Map<Id,String> mapSectionDisplayType{get; set;}
    public Map<Id,Boolean> mapOnchangeRequired{get; set;}
    private map<Id,String> mapInputValuesEdit;
    private SObject defaultValueRecord;
    public Boolean isLocked{get; set;} 
    public Boolean isSingleResponseSurvey{get; set;}
    public Boolean isFormEditable{get; set;} 
    Public String sobjectRecordName{get; set;}
    private set<Id> setRefCCInputIds = new set<Id>();
    private Boolean recursionCall;
    private map<Id,String> mapFormAllInputValues;
    
    //Wrapper class List
    public List<InputConditionWrapperClass> listInputConditionWrappper {get;set;}
    public map<Id,InputConditionWrapperClass> mapInputWrapper {get; set;}
    
    //Json String variables
    public String lstSectionJson {get; set;}
    public String mapIDInputFieldNameJson {get; set;}
    public String mapIDSectionInputJson {get; set;}
    
    public String strButtonOverride {get;set;}//string used to store button override value
    public String strOverrideMessage {get;set;}//String used to store button overrride message value
    
    /* Global variables */
        
    //Constructor
    public List_SurveyFormController_R4_Clone() {
        
        try {
            
            validForm = true;
            strButtonOverride = '';
            strOverrideMessage = '';
            String childTemplateId = ApexPages.currentPage().getParameters().get('childTemplateId');
            recordId = ApexPages.currentPage().getParameters().get('recordId');
            
            if(String.isNotBlank(childTemplateId)){
                displayTemplateById(childTemplateId);
            }
            else{
                
                //Get Ids from URL
                idTemplate = ApexPages.currentPage().getParameters().get('idTemplate');
                lrsId = ApexPages.currentPage().getParameters().get('lrsId');
                
                //Call when New template 
                if(idTemplate != '' && idTemplate != null && lrsId == null) { 
                    fetchTemplateSectionInput(idTemplate);
                }
                //Call when Edit template
                else if(idTemplate != '' && idTemplate != null && lrsId != null) {
                    fetchResponseSetInputValues(idTemplate,lrsId);
                }
                else{
                    validForm = false;
                    pageMessage = 'No Master template ID in URL';
                }
            }
            
        }
        catch(Exception e){
             
             validForm = false;
             pageMessage = 'There was an error. Please try again. If you receive this error a second time, please contact your Salesforce system administrator and provide them the url of this page and the following error text to help resolve your issue:' + e.getMessage();
        }
        
    }
    
    //method to fetch template Sections and their Inputs
    private void fetchTemplateSectionInput(String idTemplate){
            
        objTemplate = List_Utility.getTemplateById(idTemplate);
        
        /* ZM List Phase 1 Fixes Round 3
           3.Disable Save & Submit buttons for inactive Templates*/
        if(objTemplate == null){ 
            
            isLocked = true;
            isFormEditable = true;
                                                  
            List<List_Template__c> lstTemplateLatestVersion = [SELECT Id, Name,Type__c,Version__c,Master_Template__r.Label__c,Master_Template__r.Target_Object__c,
                                                                    Release_Notes__c,Submit_Button_Override__c,Submit_Override_Message__c,Master_Template__r.Type__c
                                                               FROM List_Template__c 
                                                               WHERE Master_Template__c =: idTemplate ORDER BY CreatedDate DESC LIMIT 1];
            objTemplate = lstTemplateLatestVersion.get(0);  
        }
        system.debug('===============objTemplate=================' + objTemplate);
        
        /* ZM List Phase 1 Fixes Round 3
           1.Single Response Surveys a ==>>(v) */
        List<List_Response_Set__c> lstLRS;
        
        if(objTemplate.Master_Template__r.Type__c == 'Single Response Survey'){
            
            lstLRS = [SELECT Id,Name,Target_Record__c,Response_For__r.Type__c,Date_Time_Last_Saved__c,Response_For__c,
                                                        Response_For__r.Master_Template__c,Response_For__r.Master_Template__r.Type__c 
                                                 FROM List_Response_Set__c  
                                                 WHERE Target_Record__c =: ApexPages.currentPage().getParameters().get('recordId') 
                                                      and Response_For__r.Master_Template__r.Type__c = 'Single Response Survey'
                                                      and Response_For__r.Master_Template__c =:idTemplate
                                                 ORDER BY Date_Time_Last_Saved__c DESC LIMIT 1];
            isSingleResponseSurvey = true;
        }
        
        if(lstLRS != null && !lstLRS.isEmpty()){
            system.debug('==================lstLRS=====================' + lstLRS);
            fetchResponseSetInputValues(lstLRS.get(0).Response_For__r.Master_Template__c,lstLRS.get(0).Id);
        }
        else{
            
            strButtonOverride = objTemplate.Submit_Button_Override__c;
            strOverrideMessage = objTemplate.Submit_Override_Message__c;
            
            SObject objectRecord;
            objectRecord = Database.query('Select Id,Name From ' + objTemplate.Master_Template__r.Target_Object__c + 
                                                        ' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\''); 
            if(objectRecord != null){
                sobjectRecordName = (String)objectRecord.get('Name');     
            }
                                               
            //Sections
            lstSection = List_Utility.getListSection(objTemplate.Id);
            
            set<id> setSectionIds = new set<id>();
            
            //Get all section of template
            if(lstSection!=null && !lstSection.isEmpty()) {
                
                lstSectionJson = JSON.serialize(lstSection);
                hasSection = true;
                mapSectionShowHide = new Map<Id,String>();
                mapIDSectionInput = new Map<Id,List<List_Input__c>>();
                
                for(List_Section__c objSection : lstSection) {
                    
                    setSectionIds.add(objSection.Id);
                    mapIDSectionInput.put(objSection.Id,new List<List_Input__c>());
                }
            }
            else{
                hasSection = false;
            }
            
            //Input(Questions)
            if(setSectionIds.size() > 0){
                
                lstInput = List_Utility.getListInput(setSectionIds,null);
            }
            set<id> setInputIds = new set<id>();
            String apiNames = '';
            if(lstInput!=null && !lstInput.isEmpty()) {
                
                mapOnchangeRequired = new Map<Id,Boolean>();
                for(List_Input__c objInput : lstInput) {
                    
                    if(String.isNotBlank(objInput.Default_Value__c)){
                        if(objInput.Default_Value__c.charAt(0) != 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) != 34) { 
                            if(apiNames == ''){
                                apiNames = objInput.Default_Value__c;  
                            }
                            else{
                                apiNames = apiNames +  ','  + objInput.Default_Value__c;  
                            }
                        }
                    }
                    setInputIds.add(objInput.Id);
                    mapOnchangeRequired.put(objInput.Id,False);
                }
            }
            
            //InputMap
            if(setInputIds.size() > 0) {
                
                List<List_Input_Map__c> lstInputMap = List_Utility.getListInputMap(setInputIds);
                
                if(lstInputMap != null && !lstInputMap.isEmpty()) {
                    
                    setCustomValidateInput = new set<Id>();
                    mapIDInputFieldName = new Map<Id, String>();
                    for(List_Input_Map__c objInputMap : lstInputMap) {
                        
                        if(objInputMap.Target__c == False){
                            setCustomValidateInput.add(objInputMap.List_Input__c);
                        }
                        mapIDInputFieldName.put(objInputMap.List_Input__c,objInputMap.Target_Field__c);
                    }
                    mapIDInputFieldNameJson = JSON.serialize(mapIDInputFieldName);
                    
                    //Check List input has input map or not based on that make custom validation null
                    set<Id> setCustomValidateInputTemp = new Set<Id>();
                    setCustomValidateInputTemp.addAll(setInputIds);
                    setCustomValidateInputTemp.removeAll(mapIDInputFieldName.keyset());
                    system.debug('===setCustomValidateInputTemp=='+setCustomValidateInputTemp);
                    
                    if(setCustomValidateInputTemp.size() > 0){
                        
                        setCustomValidateInput.addAll(setCustomValidateInputTemp);
                    }
                }  
                
                
            }
            
            //Default value assign to List Input
            if(lstInput!=null && !lstInput.isEmpty()) {
                
                mapIDInputPicklistJson = new Map<Id, String>();
                mapIDInputPicklist = new Map<Id,List<List_Input__c>>();
                system.debug('===================apiNames=====================' + apiNames);
                if(apiNames != ''){
                    defaultValueRecord = Database.query('Select ' + apiNames + ' From ' + objTemplate.Master_Template__r.Target_Object__c + 
                                                        ' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\'');    
                }
                
               
                for(List_Input__c objInput : lstInput) {
                    
                    if(objInput.Type__c == 'Picklist' || objInput.Type__c == 'Multi-Select Picklist') {
                        mapIDInputPicklist.put(objInput.Id,new List<List_Input__c>());
                    }
                    
                    //if(mapIDSectionInput.containsKey(objInput.List_Section__c) && mapIDInputFieldName.containsKey(objInput.Id)){
                    if(mapIDSectionInput.containsKey(objInput.List_Section__c)){
                        
                        if(String.isNotBlank(objInput.Default_Value__c)){
                            
                            if(objInput.Default_Value__c.charAt(0) == 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) == 34) {  
                                objInput.Default_Value__c = objInput.Default_Value__c.substring(1,objInput.Default_Value__c.length()-1);
                            }
                            else{
                                if(defaultValueRecord.get(objInput.Default_Value__c) != null){
                                    
                                    if(objInput.Type__c == 'Date'){
                                        Date dt = date.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
                                        objInput.Default_Value__c = String.valueOf(dt.format());
                                    }
                                    else{
                                        objInput.Default_Value__c = String.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
                                    }
                                }
                                else{
                                    objInput.Default_Value__c = null;
                                }
                                
                            }
                        }
                        
                        if(setCustomValidateInput != null && !setCustomValidateInput.isEmpty() && setCustomValidateInput.contains(objInput.Id)){
                            objInput.Custom_Data_Validation__c = null;
                        }
                        mapIDSectionInput.get(objInput.List_Section__c).add(objInput);
                    }
                }
            }
            
            
            if(mapIDSectionInput != null && !mapIDSectionInput.isEmpty()) {
                
                /*String strSerilazedJson = JSON.serializePretty(mapIDSectionInput);*/
                mapIDSectionInputJson = JSON.serializePretty(mapIDSectionInput);
                mapFormAllInputValues = GetAllInputValues(mapIDSectionInput);
            }
            system.debug('========mapFormAllInputValues size===============' + mapFormAllInputValues.size());
            system.debug('========mapFormAllInputValues ===============' + mapFormAllInputValues);
            
            //Picklist Options
            List<List_Input__c> lstOptions = new List<List_Input__c>();
            
            if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
                
                //fetch all Child Input 
                lstOptions = List_Utility.getListInput(null,mapIDInputPicklist.keySet());              
                for(List_Input__c objInput : lstOptions) {
                     
                    if(mapIDInputPicklist.containsKey(objInput.Defined_By__c)) {
                        
                        mapIDInputPicklist.get(objInput.Defined_By__c).add(objInput);
                    }
                }
            }
            
            //Put picklist map data into Json Format used in Javascript
            if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
                
                for(Id objId: mapIDInputPicklist.keyset()) {
                    
                    mapIDInputPicklistJson.put(objId, JSON.serialize(mapIDInputPicklist.get(objId)));
                }
            }
            System.debug('=================mapIDInputPicklistJson=================' + mapIDInputPicklistJson);
            
            //get all condition for Sections and Inputs
            if(setSectionIds.size() > 0 || setInputIds.size() > 0) {
                lstCondition = List_Utility.getListCondition(setSectionIds,setInputIds);
            }
            
            set<ID> setConditions = new set<ID>();
            
            //seprate Section and Input map
            if(lstCondition != null && !lstCondition.isEmpty()) {
                
                Map<ID,List<List_Condition__c>> mapSectionConditions = new Map<ID,List<List_Condition__c>>();
                Map<ID,List<List_Condition__c>> mapInputConditions  = new Map<ID,List<List_Condition__c>>();
                
                for(List_Condition__c objCondition : lstCondition) {
                    
                    setConditions.add(objCondition.ID);
                    if(objCondition.Defined_By_Section__c != null){
                        
                        if(mapSectionConditions.containsKey(objCondition.Defined_By_Section__c)) {
                            mapSectionConditions.get(objCondition.Defined_By_Section__c).add(objCondition);
                        }
                        else{
                            mapSectionConditions.put(objCondition.Defined_By_Section__c, new List<List_Condition__c> { objCondition });
                        }
                    }
                    else if(objCondition.Defined_By_Input__c != null){
                        
                        if(mapInputConditions.containsKey(objCondition.Defined_By_Input__c)){
                            mapInputConditions.get(objCondition.Defined_By_Input__c).add(objCondition);
                        }
                        else{
                            mapInputConditions.put(objCondition.Defined_By_Input__c, new List<List_Condition__c> { objCondition });
                        }
                    }
                }
            }
            
            //Call sectionInputShowHide Onload of Form
            if(setSectionIds.size() > 0 && setInputIds.size() > 0){
                sectionInputShowHide(setSectionIds,setInputIds);
            }
            
        }
    }
    
    /* ZM List Phase 1 Fixes Specs R4
    7) ENHANCE: Opening a Version of a Template that is not active */
    private void displayTemplateById(String idTemplate){
        
        objTemplate = List_Utility.getTemplateByChildId(idTemplate);
        SObject objectRecord;
        objectRecord = Database.query('Select Id,Name From ' + objTemplate.Master_Template__r.Target_Object__c + 
                                                    ' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\''); 
        if(objectRecord != null){
            sobjectRecordName = (String)objectRecord.get('Name');     
        }
        
        system.debug('============================displayTemplateById==============' + idTemplate);
        isLocked = true;
        isFormEditable = true;
        //Sections
            lstSection = List_Utility.getListSection(idTemplate);
            
            set<id> setSectionIds = new set<id>();
            
            //Get all section of template
            if(lstSection!=null && !lstSection.isEmpty()) {
                
                lstSectionJson = JSON.serialize(lstSection);
                hasSection = true;
                mapSectionShowHide = new Map<Id,String>();
                mapIDSectionInput = new Map<Id,List<List_Input__c>>();
                
                for(List_Section__c objSection : lstSection) {
                    
                    setSectionIds.add(objSection.Id);
                    mapIDSectionInput.put(objSection.Id,new List<List_Input__c>());
                }
            }
            else{
                hasSection = false;
            }
            
            //Input(Questions)
            if(setSectionIds.size() > 0){
                
                lstInput = List_Utility.getListInput(setSectionIds,null);
            }
            set<id> setInputIds = new set<id>();
            String apiNames = '';
            if(lstInput!=null && !lstInput.isEmpty()) {
                
                mapOnchangeRequired = new Map<Id,Boolean>();
                for(List_Input__c objInput : lstInput) {
                    
                    if(String.isNotBlank(objInput.Default_Value__c)){
                        if(objInput.Default_Value__c.charAt(0) != 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) != 34) { 
                            if(apiNames == ''){
                                apiNames = objInput.Default_Value__c;  
                            }
                            else{
                                apiNames = apiNames +  ','  + objInput.Default_Value__c;  
                            }
                        }
                    }
                    setInputIds.add(objInput.Id);
                    mapOnchangeRequired.put(objInput.Id,False);
                }
            }
            
            //InputMap
            if(setInputIds.size() > 0) {
                
                List<List_Input_Map__c> lstInputMap = List_Utility.getListInputMap(setInputIds);
                
                if(lstInputMap != null && !lstInputMap.isEmpty()) {
                    
                    setCustomValidateInput = new set<Id>();
                    mapIDInputFieldName = new Map<Id, String>();
                    for(List_Input_Map__c objInputMap : lstInputMap) {
                        
                        if(objInputMap.Target__c == False){
                            setCustomValidateInput.add(objInputMap.List_Input__c);
                        }
                        mapIDInputFieldName.put(objInputMap.List_Input__c,objInputMap.Target_Field__c);
                    }
                    mapIDInputFieldNameJson = JSON.serialize(mapIDInputFieldName);
                    
                    //Check List input has input map or not based on that make custom validation null
                    set<Id> setCustomValidateInputTemp = new Set<Id>();
                    setCustomValidateInputTemp.addAll(setInputIds);
                    setCustomValidateInputTemp.removeAll(mapIDInputFieldName.keyset());
                    system.debug('===setCustomValidateInputTemp=='+setCustomValidateInputTemp);
                    
                    if(setCustomValidateInputTemp.size() > 0){
                        
                        setCustomValidateInput.addAll(setCustomValidateInputTemp);
                    }
                }  
                
                
            }
            
            //Default value assign to List Input
            if(lstInput!=null && !lstInput.isEmpty()) {
                
                mapIDInputPicklistJson = new Map<Id, String>();
                mapIDInputPicklist = new Map<Id,List<List_Input__c>>();
                system.debug('===================apiNames=====================' + apiNames);
                if(apiNames != ''){
                    defaultValueRecord = Database.query('Select ' + apiNames + ' From ' + objTemplate.Master_Template__r.Target_Object__c + 
                                                        ' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\'');    
                }
                
               
                for(List_Input__c objInput : lstInput) {
                    
                    if(objInput.Type__c == 'Picklist' || objInput.Type__c == 'Multi-Select Picklist') {
                        mapIDInputPicklist.put(objInput.Id,new List<List_Input__c>());
                    }
                    
                    if(mapIDSectionInput.containsKey(objInput.List_Section__c)){
                        
                        if(String.isNotBlank(objInput.Default_Value__c)){
                            
                            if(objInput.Default_Value__c.charAt(0) == 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) == 34) {  
                                objInput.Default_Value__c = objInput.Default_Value__c.substring(1,objInput.Default_Value__c.length()-1);
                            }
                            else{
                                if(defaultValueRecord.get(objInput.Default_Value__c) != null){
                                    
                                    if(objInput.Type__c == 'Date'){
                                        Date dt = date.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
                                        objInput.Default_Value__c = String.valueOf(dt.format());
                                    }
                                    else{
                                        objInput.Default_Value__c = String.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
                                    }
                                }
                                else{
                                    objInput.Default_Value__c = null;
                                }
                                
                            }
                        }
                        
                        if(setCustomValidateInput != null && !setCustomValidateInput.isEmpty() && setCustomValidateInput.contains(objInput.Id)){
                            objInput.Custom_Data_Validation__c = null;
                        }
                        mapIDSectionInput.get(objInput.List_Section__c).add(objInput);
                    }
                }
            }
            
            if(mapIDSectionInput != null && !mapIDSectionInput.isEmpty()) {
                mapIDSectionInputJson = JSON.serializePretty(mapIDSectionInput);
            }
            
            //Picklist Options
            List<List_Input__c> lstOptions = new List<List_Input__c>();
            if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
                
                //fetch all Child Input 
                lstOptions = List_Utility.getListInput(null,mapIDInputPicklist.keySet());              
                for(List_Input__c objInput : lstOptions) {
                     
                    if(mapIDInputPicklist.containsKey(objInput.Defined_By__c)) {
                        
                        mapIDInputPicklist.get(objInput.Defined_By__c).add(objInput);
                    }
                }
            }
            
            //Put picklist map data into Json Format used in Javascript
            if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
                
                for(Id objId: mapIDInputPicklist.keyset()) {
                    
                    mapIDInputPicklistJson.put(objId, JSON.serialize(mapIDInputPicklist.get(objId)));
                }
            }
            System.debug('=================mapIDInputPicklistJson=================' + mapIDInputPicklistJson);
            
            //get all condition for Sections and Inputs
            if(setSectionIds.size() > 0 || setInputIds.size() > 0) {
                lstCondition = List_Utility.getListCondition(setSectionIds,setInputIds);
            }
            
            set<ID> setConditions = new set<ID>();
            
            //seprate Section and Input map
            if(lstCondition != null && !lstCondition.isEmpty()) {
                
                Map<ID,List<List_Condition__c>> mapSectionConditions = new Map<ID,List<List_Condition__c>>();
                Map<ID,List<List_Condition__c>> mapInputConditions  = new Map<ID,List<List_Condition__c>>();
                
                for(List_Condition__c objCondition : lstCondition) {
                    
                    setConditions.add(objCondition.ID);
                    if(objCondition.Defined_By_Section__c != null){
                        
                        if(mapSectionConditions.containsKey(objCondition.Defined_By_Section__c)) {
                            mapSectionConditions.get(objCondition.Defined_By_Section__c).add(objCondition);
                        }
                        else{
                            mapSectionConditions.put(objCondition.Defined_By_Section__c, new List<List_Condition__c> { objCondition });
                        }
                    }
                    else if(objCondition.Defined_By_Input__c != null){
                        
                        if(mapInputConditions.containsKey(objCondition.Defined_By_Input__c)){
                            mapInputConditions.get(objCondition.Defined_By_Input__c).add(objCondition);
                        }
                        else{
                            mapInputConditions.put(objCondition.Defined_By_Input__c, new List<List_Condition__c> { objCondition });
                        }
                    }
                }
            }
            
            //Call sectionInputShowHide Onload of Form
            if(setSectionIds.size() > 0 && setInputIds.size() > 0){
                sectionInputShowHide(setSectionIds,setInputIds);
            }
    }
    
    //method to fetch template Sections and their Inputs from List_Response__c
    private void fetchResponseSetInputValues(String idTemplate,String IdLRS){
        
        //Checked LRS is locked or not
        String inActiveTemplateId;
        if(IdLRS != null){
            List<List_Response_Set__c> lstListResponseSet = List_Utility.getListResponseSet(IdLRS,'');
            isLocked = lstListResponseSet.get(0).Locked__c;
            inActiveTemplateId = lstListResponseSet.get(0).Response_For__c;
        }
        system.debug('===========isLocked =============' + isLocked);
        
        List<List_Response__c> lstResponse = List_Utility.getListResponse(IdLRS);
        Map<Id,List_Response__c> mapInputListResponse = new Map<Id,List_Response__c>();
        mapInputValuesEdit = new map<Id,String>(); 
        
        if(lstResponse != null && !lstResponse.isEmpty()){
            for(List_Response__c objResponse : lstResponse){
                mapInputListResponse.put(objResponse.List_Input__c,objResponse);
                mapInputValuesEdit.put(objResponse.List_Input__c,objResponse.Response__c);
            }
        }
        system.debug('===========mapInputListResponse =============' + mapInputListResponse);
        
        //Add code for Response_For__r.Active__c == false and  LRS is Locked               
        if(isLocked == true && String.isNotBlank(inActiveTemplateId)){
            List<List_Template__c> lstTemplate = [SELECT Id, Name,Type__c,Version__c,Master_Template__r.Label__c,Master_Template__r.Target_Object__c,Release_Notes__c,
                                                        Submit_Button_Override__c,Submit_Override_Message__c,Master_Template__r.Type__c
                                                  FROM List_Template__c 
                                                  WHERE Id =: inActiveTemplateId LIMIT 1];
            objTemplate = lstTemplate.get(0);
            if(objTemplate.Master_Template__r.Type__c == 'Single Response Survey'){
                isSingleResponseSurvey = true;
            }
        }
        else
        {
            objTemplate = List_Utility.getTemplateById(idTemplate);
            
            /* ZM List Phase 1 Fixes Round 3
               3.Disable Save & Submit buttons for inactive Templates*/
            if(objTemplate == null){
                
                isLocked = true;
                isFormEditable = true;
                List<List_Template__c> lstTemplate = [SELECT Id, Name,Type__c,Version__c,Master_Template__c
                                                      FROM List_Template__c 
                                                      WHERE Id =: inActiveTemplateId LIMIT 1];
                                                      
                List<List_Template__c> lstTemplateLatestVersion = [SELECT Id, Name,Type__c,Version__c,Master_Template__r.Label__c,Master_Template__r.Target_Object__c,
                                                                    Release_Notes__c,Submit_Button_Override__c,Submit_Override_Message__c,Master_Template__r.Type__c 
                                                                  FROM List_Template__c 
                                                                  WHERE Master_Template__c =: lstTemplate.get(0).Master_Template__c ORDER BY CreatedDate DESC LIMIT 1];
                objTemplate = lstTemplateLatestVersion.get(0);  
            }
        }
        if(objTemplate.Master_Template__r.Type__c == 'Single Response Survey'){
            isSingleResponseSurvey = true;
        }

        system.debug('===============objTemplate=====================' + objTemplate);
        strOverrideMessage = objTemplate.Submit_Override_Message__c;
        strButtonOverride = objTemplate.Submit_Button_Override__c;
        
        //Get sobect record based on only require field
        SObject objectRecord;
        objectRecord = Database.query('Select Id,Name From ' + objTemplate.Master_Template__r.Target_Object__c + 
                                                    ' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\''); 
        if(objectRecord != null){
            sobjectRecordName = (String)objectRecord.get('Name');     
        }
        
        //Sections
        lstSection = List_Utility.getListSection(objTemplate.Id);
        
        set<id> setSectionIds = new set<id>();
        
        //Get all section of template
        if(lstSection!=null && !lstSection.isEmpty()) {
            
            lstSectionJson = JSON.serialize(lstSection);
            hasSection = true;
            mapSectionShowHide = new Map<Id,String>();
            mapIDSectionInput = new Map<Id,List<List_Input__c>>();
            
            for(List_Section__c objSection : lstSection) {
                
                setSectionIds.add(objSection.Id);
                mapIDSectionInput.put(objSection.Id,new List<List_Input__c>());
            }
        }
        else{
            hasSection = false;
        }
        
        //Input(Questions)
        if(setSectionIds.size() > 0){
            
            lstInput = List_Utility.getListInput(setSectionIds,null);
        }
        set<id> setInputIds = new set<id>();
        
        if(lstInput!=null && !lstInput.isEmpty()) {
            
            mapOnchangeRequired = new Map<Id,Boolean>();
            for(List_Input__c objInput : lstInput) {
                setInputIds.add(objInput.Id);
                mapOnchangeRequired.put(objInput.Id,False);
            }
        }
        
        //InputMap
        if(setInputIds.size() > 0) {
            
            List<List_Input_Map__c> lstInputMap = List_Utility.getListInputMap(setInputIds);
            if(lstInputMap != null && !lstInputMap.isEmpty()) {
                
                setCustomValidateInput = new set<Id>();
                mapIDInputFieldName = new Map<Id, String>();
                for(List_Input_Map__c objInputMap : lstInputMap) {
                    
                    if(objInputMap.Target__c == False){
                        setCustomValidateInput.add(objInputMap.List_Input__c);
                    }
                    mapIDInputFieldName.put(objInputMap.List_Input__c,objInputMap.Target_Field__c);
                }
                mapIDInputFieldNameJson = JSON.serialize(mapIDInputFieldName);
                
                //Check List input has input map or not based on that make custom validation null
                set<Id> setCustomValidateInputTemp = new Set<Id>();
                setCustomValidateInputTemp.addAll(setInputIds);
                setCustomValidateInputTemp.removeAll(mapIDInputFieldName.keyset());
                system.debug('===setCustomValidateInputTemp=='+setCustomValidateInputTemp);
                
                if(setCustomValidateInputTemp.size() > 0){
                    setCustomValidateInput.addAll(setCustomValidateInputTemp);
                }
            }
            
        }
        
        //get Input which have list input map
        if(lstInput!=null && !lstInput.isEmpty()) {
            
            mapIDInputPicklistJson = new Map<Id, String>();
            mapIDInputPicklist = new Map<Id,List<List_Input__c>>();
            
            for(List_Input__c objInput : lstInput) {
                
                if(objInput.Type__c == 'Picklist' || objInput.Type__c == 'Multi-Select Picklist') {
                    
                    mapIDInputPicklist.put(objInput.Id,new List<List_Input__c>());
                }
                
                if(mapIDSectionInput.containsKey(objInput.List_Section__c) ){
                    
                    if(mapInputListResponse.containsKey(objInput.ID)) {
                        objInput.Default_Value__c = mapInputListResponse.get(objInput.ID).Response__c;
                    }
                    if(setCustomValidateInput != null && !setCustomValidateInput.isEmpty() && setCustomValidateInput.contains(objInput.Id)){
                        objInput.Custom_Data_Validation__c = null;
                    } 
                    mapIDSectionInput.get(objInput.List_Section__c).add(objInput);
                }
            }
        }
        
        if(mapIDSectionInput != null && !mapIDSectionInput.isEmpty()) {
            
            /*String strSerilazedJson = JSON.serializePretty(mapIDSectionInput);*/
            mapIDSectionInputJson =JSON.serializePretty(mapIDSectionInput);
            mapFormAllInputValues = GetAllInputValues(mapIDSectionInput);
        }
        
        //Picklist Options
        set<Id> setAnswerInputs = new set<Id>();
        List<List_Input__c> lstOptions = new List<List_Input__c>();
        
        if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
            
            //fetch all Child Input 
            lstOptions = List_Utility.getListInput(null,mapIDInputPicklist.keySet());
            for(List_Input__c objInput : lstOptions) {
                 
                if(mapIDInputPicklist.containsKey(objInput.Defined_By__c)) {
                    
                    mapIDInputPicklist.get(objInput.Defined_By__c).add(objInput);
                    setAnswerInputs.add(objInput.Id);
                }
            }
        }
        
        //Put picklist map data into Json Format used in Javascript
        if(mapIDInputPicklist!=null && !mapIDInputPicklist.isEmpty()){
            
            for(Id objId: mapIDInputPicklist.keyset()) {
                
                mapIDInputPicklistJson.put(objId, JSON.serialize(mapIDInputPicklist.get(objId)));
            }
        }
        
        //Call sectionInputShowHide Onload of Edit Form
        if(setSectionIds.size() > 0 && setInputIds.size() > 0){
            sectionInputShowHide(setSectionIds,setInputIds);
        }
        
    }
    
    /*Updated method on 25th May according to ticket ZMlist phase 1 fixes R2*/
    //Save response based on Type
    public PageReference saveResponse(){
    
        try {
            
            //Check SaveDraft function completed successfully or not
            if(saveDraft(saveType) == true) {
                
                recordId = ApexPages.currentPage().getParameters().get('recordId');
                
                //Check whether submit or saveDraft is called
                if(saveType == 'Submit' && recordId != null) {
                    
                    fetchResponseSetInputValues(ApexPages.currentPage().getParameters().get('idTemplate'),lrsId);
                    validForm = true;
                    pageMessage = 'Survey form submitted successfully!';
                }
                else{
                    
                    fetchResponseSetInputValues(ApexPages.currentPage().getParameters().get('idTemplate'),lrsId);
                    validForm = true;
                    pageMessage = 'Survey form saved successfully!';
                }
            }
            
        }
        catch(Exception e) {
            validForm = false;
            pageMessage = 'There was an error attempting to save your progress. Please try again. If you receive this error a second time, please contact your Salesforce system administrator and provide them the url of this page and the following error text to help resolve your issue:' + e.getMessage();
        }
        return null; 
    }
    
    //Save record on draft
    private Boolean saveDraft(string saveType) {
        
        system.debug('Save draft called');
        //Start save point for insert or update data
        Savepoint sp = Database.setSavepoint();
        map<ID,String> mapVisibleInputValues = new map<ID,String>();
        
        try {
            
            String para = Apexpages.currentPage().getParameters().get('FieldValue');
            List<Map<String, string>> mapFieldValues = (List<Map<String, string>>)JSON.deserialize(para, List<Map<String, string>>.class); 
            
            //get Input value with ID in servey form
            for(Map<String, string> m : mapFieldValues)
            {
               mapInputValues.put(Id.valueOf(m.get('InputId')),m.get('value'));
               mapVisibleInputValues.put(Id.valueOf(m.get('InputId')),m.get('value'));
            }
            
            //Sobject
            String objectStr = objTemplate.Master_Template__r.Target_Object__c;
            Schema.SObjectType convertType = Schema.getGlobalDescribe().get(objectStr);
            Sobject genericObject = convertType.newSObject();
            
            system.debug('mapFieldValues========='+mapFieldValues);
            //Check submit button call for inserting sobect record 
            if(saveType == 'Submit')
            {
                set<ID> setInputIds = new set<ID>();
                 for(Id inputId : mapInputValues.keyset())
                {

                   // String InputId;
                    //InputId = m.get('InputId');
                    setInputIds.add(inputId);
                }
            
                List<List_Input_Map__c> lstInputMap = [SELECT Id,Name,List_Input__c,Target_Field__c 
                                                   FROM List_Input_Map__c 
                                                   WHERE List_Input__c IN : setInputIds and Target__c = True];
                                                   
                set<ID> setInputToUpdate = new set<ID>();
                Map<Id,String> mapInputApiName = new Map<Id,String>();
                if(lstInputMap != null && !lstInputMap.isEmpty()){
                    for(List_Input_Map__c objLIM : lstInputMap){
                        setInputToUpdate.add(objLIM.List_Input__c);
                        mapInputApiName.put(objLIM.List_Input__c,objLIM.Target_Field__c);
                    }
                }
                
                //template Sobject record data
                for(Id inputId : mapInputValues.keyset())
                {
                    
                    String value;
                    //String InputId;
                    //InputId = m.get('InputId');
                    /*APIName = m.get('APIName');*/
                     value = mapInputValues.get(inputId);

                    if(mapInputApiName.containsKey(ID.valueOf(InputId))){
                        
                        Map<String, Schema.SObjectField> objectFields = Schema.getGlobalDescribe().get(objectStr).getDescribe().fields.getMap();
                        Schema.SObjectField field = objectFields.get(mapInputApiName.get(ID.valueOf(InputId)));
                        Schema.DisplayType fieldType = field.getDescribe().getType();
                        
                        //Check Datatype of field based on that type cast it
                        if((fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Double || 
                           fieldType == Schema.DisplayType.Percent) && String.isNotBlank(value)) 
                        {
                            genericObject.put(mapInputApiName.get(ID.valueOf(InputId)), decimal.valueOf(value)); 
                        }
                        else if(fieldType == Schema.DisplayType.Integer && String.isNotBlank(value)) {
                            genericObject.put(mapInputApiName.get(ID.valueOf(InputId)), Integer.valueOf(value)); 
                        }
                        else if(fieldType == Schema.DisplayType.Boolean && String.isNotBlank(value))
                        {
                            genericObject.put(mapInputApiName.get(ID.valueOf(InputId)), Boolean.valueOf(value)); 
                        }                   
                        else if(fieldType == Schema.DisplayType.Date && String.isNotBlank(value))
                        {
                            genericObject.put(mapInputApiName.get(ID.valueOf(InputId)), date.parse(value)); 
                        }                
                        else
                        {
                            if(String.isNotBlank(value)){
                                genericObject.put(mapInputApiName.get(ID.valueOf(InputId)),value);
                            }
                        }
                    }
                    
                }
                
                //Insert Sobject Record
                if(genericObject != null){
                    
                    String recordId = ApexPages.currentPage().getParameters().get('recordId');
                    genericObject.put('Id',recordId);
                    update genericObject;
                }
            }
            
            /* */
            List<List_Response_Set__c> lstLRSSingleResponseSurvey = [SELECT Id,Name,Target_Record__c,Response_For__r.Type__c,Locked__c,Version_Number__c,Date_Time_Last_Saved__c  
                                                                    FROM List_Response_Set__c 
                                                                    WHERE Target_Record__c =: ApexPages.currentPage().getParameters().get('recordId') 
                                                                          AND Response_For__r.Master_Template__r.Type__c = 'Single Response Survey'  
                                                                    ORDER BY Date_Time_Last_Saved__c DESC 
                                                                    LIMIT 1];
            
            
            //Conditions to insert or Update List_Response_Set__c object
            if(lrsId == null) {
                
                List<List_Response__c> lstResponse = new List<List_Response__c>();
                
                //Insert List_Response_Set__c Record
                List_Response_Set__c objRS = new List_Response_Set__c();
                objRS.Date_Time_Last_Saved__c = datetime.now();
                objRS.Response_For__c = objTemplate.Id;
                objRS.Target_Record__c = ApexPages.currentPage().getParameters().get('recordId');
                objRS.Submitted_By__c = UserInfo.getUserId();
                
                if(objTemplate.Master_Template__r.Type__c == 'Single Response Survey'){
                    
                    if(lstLRSSingleResponseSurvey != null && !lstLRSSingleResponseSurvey.isEmpty()){
                        objRS.Version_Number__c = lstLRSSingleResponseSurvey.get(0).Version_Number__c + 1;
                    }
                    else{
                        objRS.Version_Number__c = 1;
                    }
                }
               
                if(saveType == 'Submit') {
                    objRS.Status__c = 'Submitted';
                }
                else{
                    objRS.Status__c = 'Draft';
                }
                insert objRS;
                
                
                //List response record data
                
                /* Hidden input Default_Value__c for List Response */
               
                map<Id,String> mapAllInputValues = GetAllInputValues(mapIDSectionInput);
                for(Id inputID : mapAllInputValues.keyset()){

                	List_Response__c objListResponse = new List_Response__c();
                	
                	objListResponse.Date_Time_Last_Saved__c = datetime.now();
                	objListResponse.List_Input__c = inputID;
                	if(mapVisibleInputValues.containsKey(inputID)){
                		objListResponse.Response__c = mapVisibleInputValues.get(inputID);
                	}
                	else{
                		objListResponse.Response__c = mapAllInputValues.get(inputID);
                	}
                	objListResponse.Response_Set__c = objRS.Id;
                	lstResponse.add(objListResponse);
                }
                
                /* Hidden input Default_Value__c for List Response */
                
                //Insert List_Response__c Record
                if(lstResponse != null || !lstResponse.isEmpty()) {
                    insert lstResponse;
                    lrsId = objRS.Id;
                }
                return true;
            }
            else{
                
                //Update status of list Response_Set__c
                for(List_Response_Set__c objLRS : List_Utility.getListResponseSet(lrsId,'')){
                    
                    objLRS.Date_Time_Last_Saved__c = datetime.now();
                    if(saveType == 'Submit') {
                        objLRS.Status__c = 'Submitted';
                    }
                    else{
                        objLRS.Status__c = 'Draft';
                    }
                    Update objLRS;
                    lrsId = objLRS.Id;
                }
                
                //Update List response
                List<List_Response__c> lstResponseToUpdate = new List<List_Response__c>();
                List<List_Response__c> lstResponseToInsert = new List<List_Response__c>();
                map<ID,List_Response__c> mapInputIDListResponse = new map<ID,List_Response__c>();
                
                for(List_Response__c objResponse : List_Utility.getListResponse(lrsId))
                {
                     mapInputIDListResponse.put(objResponse.List_Input__c,objResponse);               
                }
                
                if(mapInputIDListResponse != null && !mapInputIDListResponse.isEmpty()){
                    
                    system.debug('===============mapInputValues size====================' + mapInputValues.size());
                    system.debug('===============mapVisibleInputValues====================' + mapVisibleInputValues.size());
                    
                    map<Id,String> mapAllInputValues = GetAllInputValues(mapIDSectionInput);
                    for(Id InputId : mapAllInputValues.keyset()) 
                    {
                    
                        String value;
                        if(mapVisibleInputValues.containsKey(InputId)){
                    		value = mapVisibleInputValues.get(InputId);
                    	}
                    	else{
                    		value = mapAllInputValues.get(InputId);
                    	}
                        //value = mapInputValues.get(InputId);
                        
                        if(mapInputIDListResponse.containsKey(Id.valueOf(InputId))){
                            
                            string var = mapInputIDListResponse.get(Id.valueOf(InputId)).Response__c == null ? '' : mapInputIDListResponse.get(Id.valueOf(InputId)).Response__c;
                            //Check value is updated for List Response 
                            if(value != var){
                                
                                mapInputIDListResponse.get(Id.valueOf(InputId)).Date_Time_Last_Saved__c = datetime.now();
                                mapInputIDListResponse.get(Id.valueOf(InputId)).Response__c = value;
                                lstResponseToUpdate.add(mapInputIDListResponse.get(Id.valueOf(InputId)));
                            }
                        }
                        else{
                            
                            //Insert new response if any new field added in Template after save
                            List_Response__c objLR = new List_Response__c();
                            objLR.Date_Time_Last_Saved__c = datetime.now();
                            objLR.List_Input__c = InputId;
                            objLR.Response__c = value;
                            objLR.Response_Set__c = ID.valueOf(lrsId);
                            lstResponseToInsert.add(objLR);
                        }
                    }
                }
                
                if(lstResponseToUpdate != null && !lstResponseToUpdate.isEmpty()){
                    update lstResponseToUpdate;
                }
                if(lstResponseToInsert != null && !lstResponseToInsert.isEmpty()){
                    Insert lstResponseToInsert;
                }
                return true;
            }
        }
        catch(Exception e) {
            
            validForm = false;
            pageMessage = 'There was an error attempting to save your progress. Please try again. If you receive this error a second time, please contact your Salesforce system administrator and provide them the url of this page and the following error text to help resolve your issue:' + e.getMessage();
            Database.rollback(sp);
            return false;
        }
    }
    
    //Get all List-input with it's defualt value in current Template
    private map<Id,String> GetAllInputValues(Map<Id,List<List_Input__c>> mapIDSectionInput) {
        
        map<Id,String> mapAllInputValues = new map<Id,String>();
        String apiNames = '';
        set<String> setApiNames = new set<String>();
        List<String> lstApiNames = new List<String>();
        for(Id sectionId : mapIDSectionInput.keyset()){
        	for(List_Input__c objInput : List_Utility.getListInput(mapIDSectionInput.keyset(),null)){
        	
        		if(String.isNotBlank(objInput.Default_Value__c)){
        			if(objInput.Default_Value__c.charAt(0) != 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) != 34) { 
        				/*if(apiNames == ''){
        					apiNames = objInput.Default_Value__c;  
        				}
        				else{
        					apiNames = apiNames +  ','  + objInput.Default_Value__c;*/
        			    setApiNames.add(objInput.Default_Value__c);
        				/*}*/
        			}
        		}   
        	}
        }
        system.debug('===========GetAllInputValues apiNames=========' + apiNames);
        
        if(setApiNames.size() > 0){
            lstApiNames.addAll(setApiNames);
            apiNames = String.join(lstApiNames, ',');
        	defaultValueRecord = Database.query('Select ' + apiNames + ' From ' + objTemplate.Master_Template__r.Target_Object__c + 
        										' Where Id = \'' + ApexPages.currentPage().getParameters().get('recordId') +  '\'');    
        }
                
        for(Id sectionId : mapIDSectionInput.keyset()){
        	for(List_Input__c objInput : List_Utility.getListInput(mapIDSectionInput.keyset(),null)){
        	
        		if(String.isNotBlank(objInput.Default_Value__c)){
        									
        			if(objInput.Default_Value__c.charAt(0) == 34 && objInput.Default_Value__c.charAt(objInput.Default_Value__c.length()-1) == 34) {  
        				objInput.Default_Value__c = objInput.Default_Value__c.substring(1,objInput.Default_Value__c.length()-1);
        			}
        			else{
        				if(defaultValueRecord.get(objInput.Default_Value__c) != null){
        					
        					if(objInput.Type__c == 'Date'){
        						Date dt = date.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
        						objInput.Default_Value__c = String.valueOf(dt.format());
        					}
        					else{
        						objInput.Default_Value__c = String.valueOf(defaultValueRecord.get(objInput.Default_Value__c));
        					}
        				}
        				else{
        					objInput.Default_Value__c = null;
        				}
        			}
        		}
        		else{
        			objInput.Default_Value__c = null;
        		}
        		mapAllInputValues.put(objInput.Id,objInput.Default_Value__c);
        	}
        }
        
        return mapAllInputValues;
    }
    
    //Onload
    private void sectionInputShowHide(set<id> setSectionIds,set<id> setInputIds){
        
        Map<ID,string> mapIDConditionCL = new Map<ID,string>();
        Map<ID,List_Condition__c> mapIDConditionObject = new Map<ID,List_Condition__c>();
        Map<ID,List<Condition_Criteria__c>> mapIdConditionCreteria = new Map<ID,List<Condition_Criteria__c>>();
        set<ID> setConditionID = new set<ID>();
        mapSectionConditionEvaluted = new Map<ID,map<List_Condition__c,Boolean>>();
        mapSectionDisplayType = new Map<Id,String>();
        
        mapInputConditionEvaluted = new Map<ID,map<List_Condition__c,Boolean>>();
        mapInputWrapper = new map<Id,InputConditionWrapperClass>();
        Map<String,String> mapEquation = new Map<String,String>{'Equals' => '==','Does Not Equal' => '!=','Greater Than' => '>','Greater or Equal' => '>=',
                                                                'Less Than' => '<','Less or Equal' => '<='};
        
        /* Start Section Show/Hide  */
        
        //Initialize section DisplayType with default 'Show'
        for(ID sectionID : setSectionIds){
            mapSectionConditionEvaluted.put(sectionID,new map<List_Condition__c,Boolean>());
            mapSectionDisplayType.put(sectionID,'Show');
        }
        
        //Get all condition based on sectionID 
        for(List_Condition__c objCondition : [select ID,Name,Custom_Logic__c,Type__c 
                                              from List_Condition__c 
                                              where Defined_By_Section__c IN : setSectionIds AND Active__c = TRUE]){
            
            setConditionID.add(objCondition.ID);
            mapIDConditionCL.put(objCondition.ID,objCondition.Custom_Logic__c);
            mapIDConditionObject.put(objCondition.ID,objCondition);
        }
        
        // get all Condition criteria based on setConditionID
        set<String> setfld = new set<String>();
        if(setConditionID.size() > 0){
            
            //Get all Condition_Criteria__c based on setConditionID
            for(Condition_Criteria__c objCC : List_Utility.getCondition_Criteria(setConditionID)){
                
                if(mapIdConditionCreteria.containsKey(objCC.List_Condition__c)) {
                    
                    mapIdConditionCreteria.get(objCC.List_Condition__c).add(objCC);
                } 
                else{
                    mapIdConditionCreteria.put(objCC.List_Condition__c,new List<Condition_Criteria__c> { objCC });
                }
                
                //Get APINames from Tested Formula
                if(objCC.Tested_Formula__c != null){
                    
                    String[] splitter = objCC.Tested_Formula__c.split(' ');
                    setfld.add(splitter[0]);
                }
            }
        }
        
        //Fetch all Tested formula field record of Sobject
        Sobject genericObject;
        if(setfld.size() > 0){
            genericObject = GetAllSobjectFieldRecord(setfld);
        }
        
        //Evaluate Condition_Criteria
    	if(mapIdConditionCreteria.size() > 0){
    	    
    	    EvaluateCondition_Criteria('section',mapIdConditionCreteria,genericObject,mapIDConditionCL,mapEquation,mapIDConditionObject);
    	    //Update section DisplayType based on evaluate result
    	    updateSectionConditionEvaluted();
    	}
        
        /* End Section Show/Hide  */
        
        
        
        /* Start Input Show/Hide/ReadOnly/Required  */
        
        mapIDConditionCL = new Map<ID,string>();
        mapIDConditionObject = new Map<ID,List_Condition__c>();
        mapIdConditionCreteria = new Map<ID,List<Condition_Criteria__c>>();
        setConditionID = new set<ID>();
        
        //Initialize List_Input defualt Properties like(readOnly,required,Show)
        for(ID inputID : setInputIds){
            mapInputConditionEvaluted.put(inputID,new map<List_Condition__c,Boolean>());
            mapInputWrapper.put(inputID,new InputConditionWrapperClass(True,False,False));
        }
        
        /*Updated query on 23rd May 2017 according to ZMlist fixes R2*/
        //Get all condition based on setInputIds
        for(List_Condition__c objCondition : [select ID,Name,Custom_Logic__c,Type__c 
                                              from List_Condition__c 
                                              where Defined_By_Input__c IN : setInputIds AND Active__c = TRUE
                                              ORDER BY Defined_By_Input__c,Evaluation_Order__c]){
            setConditionID.add(objCondition.ID);
            mapIDConditionCL.put(objCondition.ID,objCondition.Custom_Logic__c);
            mapIDConditionObject.put(objCondition.ID,objCondition);
        }
        
        setfld = new set<String>();
        if(setConditionID.size() > 0){
            
            //Get all Condition_Criteria__c based on setConditionID
            for(Condition_Criteria__c objCC : List_Utility.getCondition_Criteria(setConditionID)){
                
                if(mapIdConditionCreteria.containsKey(objCC.List_Condition__c)) {
                    
                    mapIdConditionCreteria.get(objCC.List_Condition__c).add(objCC);
                } 
                else{
                    mapIdConditionCreteria.put(objCC.List_Condition__c,new List<Condition_Criteria__c> { objCC });
                }
                
                //Get APINames from Tested Formula
                if(objCC.Tested_Formula__c != null){
                    
                    String[] splitter = objCC.Tested_Formula__c.split(' ');
                    setfld.add(splitter[0]);
                }
                
            }
        }
        
        //Fetch all Tested formula field record of Sobject
        genericObject = null;
        if(setfld.size() > 0){
            genericObject = GetAllSobjectFieldRecord(setfld);
        }
        
        //Evaluate Condition_Criteria
    	if(mapIdConditionCreteria.size() > 0){
    	    
    	    EvaluateCondition_Criteria('input',mapIdConditionCreteria,genericObject,mapIDConditionCL,mapEquation,mapIDConditionObject);
    	    
    	    //Update List Input Properties based on evaluate result
    	    updateInputConditionEvaluted();
    	}
        
    	/* End Input Show/Hide/ReadOnly/Required  */
    	
    }
    
    /*Updated method on 25th May 2017 according to ticket ZMlist phase 1 fixes R2*/
    //Onchange
    map<Id,String> mapInputValues = new map<Id,String>();//map used to store updated values
    Map<Id,String> mapRefreshData = new Map<Id,String>();
    public PageReference sectionShowHideRefInput() {
        
        system.debug('=======sectionShowHideRefInput is called===========');
        recursionCall = null;
        List<Map<String, string>> mapFieldValues = (List<Map<String, string>>)JSON.deserialize(allFormElementData, List<Map<String, string>>.class); 
        mapInputValues = new map<Id,String>();
        Map<ID,string> mapIDConditionCL = new Map<ID,string>();
        Map<ID,List_Condition__c> mapIDConditionObject = new Map<ID,List_Condition__c>();
        Map<ID,List<Condition_Criteria__c>> mapIdConditionCreteria = new Map<ID,List<Condition_Criteria__c>>();
        set<ID> setConditionID = new set<ID>();
        mapSectionConditionEvaluted = new Map<ID,map<List_Condition__c,Boolean>>();
        Map<String,String> mapEquation = new Map<String,String>{'Equals' => '==','Does Not Equal' => '!=','Greater Than' => '>','Greater or Equal' => '>=',
                                                                'Less Than' => '<','Less or Equal' => '<='};
        
        //get Input value with ID in servey form
        for(Map<String, string> m : mapFieldValues)
        {
           mapInputValues.put(Id.valueOf(m.get('InputId')),m.get('value'));
           mapRefreshData.put(Id.valueOf(m.get('InputId')),m.get('value'));
           //system.debug('=======================mapInputValues 1===================='+m.get('InputId') + '===>>>' + m.get('value'));
        }
        
        /* Start Section Show/Hide  */
        
        //Get all Condition_Criteria based on elementID when onchange of Input
        List<Condition_Criteria__c> lstCC = List_Utility.getReference_Condition_Criteria(elementID);
        set<ID> setSectionIds = new set<ID>();
        if(lstCC != null && !lstCC.isEmpty()){
            for(Condition_Criteria__c objCC : lstCC){
                if(objCC.List_Condition__r.Defined_By_Section__c != null){
                    setSectionIds.add(objCC.List_Condition__r.Defined_By_Section__c);
                }
            }
        }
        
        set<String> setfld = new set<String>();
        if(setSectionIds.size() > 0){
            
            for(ID sectionID : setSectionIds){
                mapSectionConditionEvaluted.put(sectionID,new map<List_Condition__c,Boolean>()); 
            }
            
            /*Updated query on 23rd May 2017 according to ZMlist fixes R2*/
            //Get all List_Action based on setSectionIds 
            for(List_Condition__c objCondition : [select ID,Name,Custom_Logic__c,Type__c 
                                              from List_Condition__c 
                                              where Defined_By_Section__c IN : setSectionIds AND Active__c = TRUE
                                              ORDER BY Defined_By_Input__c, Evaluation_Order__c]){
            
                setConditionID.add(objCondition.ID);
                mapIDConditionCL.put(objCondition.ID,objCondition.Custom_Logic__c);
                mapIDConditionObject.put(objCondition.ID,objCondition);
            }
            
            //Get all Condition_Criteria of List_Condition
            for(Condition_Criteria__c objCC : [Select ID,Name,List_Condition__c,List_Input__c,Index__c,List_Condition__r.Defined_By_Section__c,
                                                    Operator__c,Tested_Formula__c,Value__c,List_Input__r.Default_Value__c,List_Input__r.Type__c  
                                              from Condition_Criteria__c 
                                              where List_Condition__r.Defined_By_Section__c IN :setSectionIds AND List_Condition__r.Active__c = TRUE
                                              ORDER BY List_Condition__r.Defined_By_Section__c, List_Condition__r.Evaluation_Order__c]){
                
                if(mapIdConditionCreteria.containsKey(objCC.List_Condition__c))
                {
                    mapIdConditionCreteria.get(objCC.List_Condition__c).add(objCC);
                } 
                else{
                    mapIdConditionCreteria.put(objCC.List_Condition__c,new List<Condition_Criteria__c> { objCC });
                }
                if(objCC.Tested_Formula__c != null){
                    
                    String[] splitter = objCC.Tested_Formula__c.split(' ');
                    setfld.add(splitter[0]);
                }
            }
        }
        
        //Fetch all Tested formula field record of Sobject
        Sobject genericObject;
        if(setfld.size() > 0){
            genericObject = GetAllSobjectFieldRecord(setfld);
        }
        
        //Evaluate Condition_Criteria
    	if(mapIdConditionCreteria.size() > 0){
    	    
    	    ReferenceEvaluateCondition_Criteria('section',mapIdConditionCreteria,genericObject,mapIDConditionCL,mapEquation,mapIDConditionObject,mapInputValues);
    	    
    	    //Update section DisplayType based on evaluate result
    	    updateSectionConditionEvaluted();
    	}
        
        /* End Section Show/Hide  */
        
        //Call input onchange
    	inputShowHideRefInput(mapInputValues);
    
    	//Rerender form perviuos data after refresh
    	/*for (ID sectionID : mapIDSectionInput.keySet()){
    	    for(List_Input__c objInput : mapIDSectionInput.get(sectionID)){
    	        if(mapInputValues.containsKey(objInput.Id)){
    	            system.debug('=======================mapInputValues 3===================='+ objInput.Id + '===>>>' + mapInputValues.get(objInput.Id));
                    objInput.Default_Value__c = mapInputValues.get(objInput.Id);
    	        }
    	    }
    	}*/
    	for (ID sectionID : mapIDSectionInput.keySet()){
    	    for(List_Input__c objInput : mapIDSectionInput.get(sectionID)){
    	        if(mapRefreshData.containsKey(objInput.Id)){
                    objInput.Default_Value__c = mapRefreshData.get(objInput.Id);
    	        }
    	    }
    	}
    	
        return null;
    }
     
    /*Updated method on 25th May according to ticket ZMlist phase 1 fixes R2*/
    //Onchange
    public void inputShowHideRefInput(map<Id,String> mapInputValues1){
        
        system.debug('=================inputShowHideRefInput elementID====================' + elementID); 
        system.debug('=================Fresh Input Values ====================' + mapInputValues1.get(elementID)); 
        
        Map<ID,string> mapIDConditionCL = new Map<ID,string>();
        Map<ID,List_Condition__c> mapIDConditionObject = new Map<ID,List_Condition__c>();
        Map<ID,List<Condition_Criteria__c>> mapIdConditionCreteria = new Map<ID,List<Condition_Criteria__c>>();
        set<ID> setConditionID = new set<ID>();
        Map<String,String> mapEquation = new Map<String,String>{'Equals' => '==','Does Not Equal' => '!=','Greater Than' => '>','Greater or Equal' => '>=',
                                                                'Less Than' => '<','Less or Equal' => '<='};
                                                                
        system.debug('=================recursionCall====================' + recursionCall); 
        if(recursionCall == null){
            mapInputConditionEvaluted = new Map<ID,map<List_Condition__c,Boolean>>();
        }
        
        //Get all Condition_Criteria based on elementID when onchange of Input
        List<Condition_Criteria__c> lstCC = List_Utility.getReference_Condition_Criteria(elementID);
        
        set<ID> setInputIds = new set<ID>();
        if(lstCC != null && !lstCC.isEmpty()){
            for(Condition_Criteria__c objCC : lstCC){
                if(objCC.List_Condition__r.Defined_By_Input__c != null){
                    setInputIds.add(objCC.List_Condition__r.Defined_By_Input__c);
                }
            }
        }
        
        set<String> setfld = new set<String>();
        if(setInputIds.size() > 0){
            
            for(ID inputID : setInputIds){
                mapInputConditionEvaluted.put(inputID,new map<List_Condition__c,Boolean>()); 
            }
            
            /*Updated query on 23rd may 2017 according Zmlist fixes R2*/ 
            //Get all List_Action based on setInputIds 
            for(List_Condition__c objCondition : [select ID,Name,Custom_Logic__c,Type__c 
                                                  from List_Condition__c 
                                                  where Defined_By_Input__c IN : setInputIds AND Active__c = TRUE
                                                  ORDER BY Defined_By_Input__c, Evaluation_Order__c]){
            
                setConditionID.add(objCondition.ID);
                mapIDConditionCL.put(objCondition.ID,objCondition.Custom_Logic__c);
                mapIDConditionObject.put(objCondition.ID,objCondition);
            }
           
           
            //Get all Condition_Criteria of List_Condition
            for(Condition_Criteria__c objCC : [Select ID,Name,List_Condition__c,List_Input__c,Index__c,List_Condition__r.Defined_By_Input__c,
                                                    Operator__c,Tested_Formula__c,Value__c,List_Input__r.Default_Value__c,List_Input__r.Type__c  
                                               from Condition_Criteria__c 
                                               where List_Condition__r.Defined_By_Input__c IN :setInputIds AND List_Condition__r.Active__c = TRUE
                                              ORDER BY List_Condition__r.Defined_By_Input__c, List_Condition__r.Evaluation_Order__c]){
                
                if(mapIdConditionCreteria.containsKey(objCC.List_Condition__c)) 
                {
                    mapIdConditionCreteria.get(objCC.List_Condition__c).add(objCC);
                } 
                else{
                    mapIdConditionCreteria.put(objCC.List_Condition__c,new List<Condition_Criteria__c> { objCC });
                }
                //Get APINames from Tested Formula
                if(objCC.Tested_Formula__c != null){
                    String[] splitter = objCC.Tested_Formula__c.split(' ');
                    setfld.add(splitter[0]);
                }
            }
        }
        
        //Fetch all Tested formula field record of Sobject
        Sobject genericObject;
        if(setfld.size() > 0){
            genericObject = GetAllSobjectFieldRecord(setfld);
        }
        
        //Evaluate Condition_Criteria
    	if(mapIdConditionCreteria.size() > 0){
    	    
    	    ReferenceEvaluateCondition_Criteria('input',mapIdConditionCreteria,genericObject,mapIDConditionCL,mapEquation,mapIDConditionObject,mapInputValues1);
    	    
    	    /*Updated code on 25th May according to ticket ZMlist phase 1 fixes R2*/
            
            /*Method being updated to get its respective childs to be hidden when condition meets criteria*/
    	    //Update List Input Properties based on evaluate result
    	    updateRefInputConditionEvaluted(mapInputValues1);
    	    
    	}
    }
    
    public Sobject GetAllSobjectFieldRecord(set<String> setfld){
        
        String fieldNames = '';
        Sobject genericObject;
        if(setfld.size() > 0){
            
            for(String fldName : setfld){
                fieldNames = fieldNames + fldName + ',';
            }
            fieldNames = fieldNames.substring(0, fieldNames.length()-1);
            String query = 'Select ' + fieldNames + ' From ' + objTemplate.Master_Template__r.Target_Object__c + ' Where Id = \'' + recordId + '\'';
            genericObject = Database.query(query);
        }
        return genericObject;
    }
    
    public void EvaluateCondition_Criteria(String sectionOrInput,Map<ID,List<Condition_Criteria__c>> mapIdConditionCreteria,Sobject genericObject,
                                                                             Map<ID,string> mapIDConditionCL,Map<String,String> mapEquation,Map<ID,List_Condition__c> mapIDConditionObject){
        
        for(ID IdLC : mapIdConditionCreteria.keySet()){
    	        
    	        String CustLC = mapIDConditionCL.get(IdLC);
    	        
    	        Map<Decimal,Boolean> mapEvalutionIndex = new Map<Decimal,Boolean>();
    	        ID SectionID;ID inputID;
    	        
    	        for(Condition_Criteria__c objCC : mapIdConditionCreteria.get(IdLC)){
    	            
    	            //Check Condition_Criteria__c has dependent List_Input
                    if(objCC.List_Input__c != null){
                        
                        mapOnchangeRequired.put(objCC.List_Input__c, True);
                        String value;
                        setRefCCInputIds.add(objCC.List_Input__c);
                        
                        //Assign Input field value on Load and Edit 
                        if(lrsId != null && mapInputValuesEdit.containsKey(objCC.List_Input__c)){
                            value = mapInputValuesEdit.get(objCC.List_Input__c);
                        }
                        else{
                            
                             if(String.isNotBlank(objCC.List_Input__r.Default_Value__c)){
                                
                                //Check default is on "" quotes or not
                                if(objCC.List_Input__r.Default_Value__c.charAt(0) == 34 && objCC.List_Input__r.Default_Value__c.charAt(objCC.List_Input__r.Default_Value__c.length()-1) == 34) {  
                                    value = objCC.List_Input__r.Default_Value__c.substring(1,objCC.List_Input__r.Default_Value__c.length()-1);
                                }
                                else{ 
                                    value = String.valueOf(defaultValueRecord.get(objCC.List_Input__r.Default_Value__c));
                                }
                            }
                        }
                        
                        Boolean eval;
                        //Checking for null with equal and Not Equal
                        if(String.isNotBlank(value)){
                            eval = List_conditionCriteriaEvalution.evaluateReferenceInputFormula(objCC.Value__c,
                                                                                                     mapEquation.get(objCC.Operator__c),
                                                                                                     value,
                                                                                                     objCC.List_Input__r.Type__c);   
                        }
                        else if(mapEquation.get(objCC.Operator__c) == '==' || mapEquation.get(objCC.Operator__c) == '!='){
                            eval = List_conditionCriteriaEvalution.evaluateReferenceInputFormula(objCC.Value__c,
                                                                                                     mapEquation.get(objCC.Operator__c),
                                                                                                     value,
                                                                                                     objCC.List_Input__r.Type__c);  
                        }
                        else{
                            eval = false;
                        }
                        mapEvalutionIndex.put(objCC.Index__c,eval);
    				}
    				else{
    				    
    					//Evaluate criteria
    					Boolean eval = List_conditionCriteriaEvalution.evaluate(genericObject,objCC.Tested_Formula__c,objCC.Operator__c,objCC.Value__c,
    					                                                        objTemplate.Master_Template__r.Target_Object__c);
    					mapEvalutionIndex.put(objCC.Index__c,eval);
    				}
    				if(sectionOrInput == 'section'){
    				    SectionID = objCC.List_Condition__r.Defined_By_Section__c;
    				}
    				else{
    				    inputID = objCC.List_Condition__r.Defined_By_Input__c;
    				}
    	        }
    	        
    	        //Based on Custom Logic evaluate Condition_Criteria
    	        if(CustLC == '' || CustLC == null){
    	            
    	            Boolean conditionMatch = True;
    	            for(Decimal eval : mapEvalutionIndex.keySet()){
    	                if(mapEvalutionIndex.get(eval) == False){
    	                    conditionMatch = False;
    	                }
    	            }
    	            if(sectionOrInput == 'section'){
    	                mapSectionConditionEvaluted.get(SectionID).put(mapIDConditionObject.get(IdLC),conditionMatch);
    	            }
                    else{
                        mapInputConditionEvaluted.get(inputID).put(mapIDConditionObject.get(IdLC),conditionMatch);
                    }
    	        }
    	        else{
    	            for(Decimal index : mapEvalutionIndex.keySet()){
            			CustLC = CustLC.replace(String.valueOf(index),String.valueOf(mapEvalutionIndex.get(index)));
            		}
            		if(sectionOrInput == 'section'){
            		    mapSectionConditionEvaluted.get(SectionID).put(mapIDConditionObject.get(IdLC),List_BooleanExpression.evaluate(CustLC));
            		}
                    else{
                        mapInputConditionEvaluted.get(inputID).put(mapIDConditionObject.get(IdLC),List_BooleanExpression.evaluate(CustLC));
                    }
    	        }
    	        
    	    }
    }
    
    map<ID,Integer> mapInputConditionEvalutedCounter = new map<ID,Integer>();
    public void ReferenceEvaluateCondition_Criteria(String sectionOrInput,Map<ID,List<Condition_Criteria__c>> mapIdConditionCreteria,Sobject genericObject,
                                                                             Map<ID,string> mapIDConditionCL,Map<String,String> mapEquation,Map<ID,List_Condition__c> mapIDConditionObject,Map<Id,String> mapNewData){
    
        for(ID IdLC : mapIdConditionCreteria.keySet()){
            
	        String CustLC = mapIDConditionCL.get(IdLC);
	        Map<Decimal,Boolean> mapEvalutionIndex = new Map<Decimal,Boolean>();
	        ID inputID;ID SectionID;
	        system.debug('Before Evalution IdLC :: ' + IdLC);
            for(Condition_Criteria__c objCC : mapIdConditionCreteria.get(IdLC)){
	            
	            system.debug('Before Evalution objCC :: ' + objCC);
	            //Check Condition_Criteria__c has dependent List_Input
                if(objCC.List_Input__c != null){
                    
                    //Assign Input field value on Load and Edit 
                    String value;
                    
                    if(elementID == String.valueOf(objCC.List_Input__c) && recursionCall != null){
                        value = mapNewData.get(elementID);
                    }
                    else if(elementID == String.valueOf(objCC.List_Input__c) && recursionCall == null){
                        value = newTextboxValue;
                    }
                    /*else if(mapInputValues.containsKey(objCC.List_Input__c) && recursionCall == null){
                        value = mapInputValues.get(objCC.List_Input__c);
                    }*/
                    else if(mapNewData.containsKey(objCC.List_Input__c)){
                        value = mapNewData.get(objCC.List_Input__c);
                    }
                    else{
                        if(String.isNotBlank(objCC.List_Input__r.Default_Value__c)){
                            if(objCC.List_Input__r.Default_Value__c.charAt(0) == 34 && objCC.List_Input__r.Default_Value__c.charAt(objCC.List_Input__r.Default_Value__c.length()-1) == 34) {  
                                value = objCC.List_Input__r.Default_Value__c.substring(1,objCC.List_Input__r.Default_Value__c.length()-1).toLowerCase();
                            }
                            else{ 
                                value = String.valueOf(defaultValueRecord.get(objCC.List_Input__r.Default_Value__c));
                            }
                        }
                    }
                    Boolean eval;
                    system.debug('Before Evalution Input Id :: ' + objCC.List_Input__c);
                    system.debug('Before Evalution Input value :: ' + value);
                    //Checking for null with equal and Not Equal
                    if(String.isNotBlank(value)){
                        eval = List_conditionCriteriaEvalution.evaluateReferenceInputFormula(objCC.Value__c,
                                                                                                 mapEquation.get(objCC.Operator__c),
                                                                                                 value,
                                                                                                 objCC.List_Input__r.Type__c);   
                    }
                    else if(mapEquation.get(objCC.Operator__c) == '==' || mapEquation.get(objCC.Operator__c) == '!='){
                        eval = List_conditionCriteriaEvalution.evaluateReferenceInputFormula(objCC.Value__c,
                                                                                                 mapEquation.get(objCC.Operator__c),
                                                                                                 value,
                                                                                                 objCC.List_Input__r.Type__c);  
                    }
                    else{
                        eval = false;
                    }
                    mapEvalutionIndex.put(objCC.Index__c,eval);
				}
				else{
					//Evaluate criteria
					Boolean eval = List_conditionCriteriaEvalution.evaluate(genericObject,objCC.Tested_Formula__c,objCC.Operator__c,objCC.Value__c,
					                                                        objTemplate.Master_Template__r.Target_Object__c);
					mapEvalutionIndex.put(objCC.Index__c,eval);
				}
				if(sectionOrInput == 'section'){
				    SectionID = objCC.List_Condition__r.Defined_By_Section__c;
				}
				else{
				    inputID = objCC.List_Condition__r.Defined_By_Input__c;
				}
				
	       }
	       
	       //Based on Custom Logic evaluate Condition_Criteria
	       if(CustLC == '' || CustLC == null) {
	           
	            Boolean conditionMatch = True;
	            for(Decimal eval : mapEvalutionIndex.keySet())
	            {
	                if(mapEvalutionIndex.get(eval) == False)
	                {
	                    conditionMatch = False;
	                }
	            }
	            
	            if(sectionOrInput == 'section'){
	                mapSectionConditionEvaluted.get(SectionID).put(mapIDConditionObject.get(IdLC),conditionMatch);
	            }
	            else{
	                mapInputConditionEvaluted.get(inputID).put(mapIDConditionObject.get(IdLC),conditionMatch);
	            }
                
	       }
	       else
	       {
                for(Decimal index : mapEvalutionIndex.keySet())
                {
                	CustLC = CustLC.replace(String.valueOf(index),String.valueOf(mapEvalutionIndex.get(index)));
                }
                system.debug('======CustLC=====' + CustLC);
	            system.debug('======inputID=====' + inputID);
                if(sectionOrInput == 'section'){
                    mapSectionConditionEvaluted.get(SectionID).put(mapIDConditionObject.get(IdLC),List_BooleanExpression.evaluate(CustLC));
                }
                else{
                    
                    mapInputConditionEvaluted.get(inputID).put(mapIDConditionObject.get(IdLC),List_BooleanExpression.evaluate(CustLC));
                }
	       }
	    }
	    system.debug('================ReferenceEvaluateCondition_Criteria recursionCall=================' + recursionCall);
	    system.debug('================ReferenceEvaluateCondition_Criteria mapInputConditionEvalutedCounter=================' + mapInputConditionEvalutedCounter);
	    if(recursionCall == null && mapInputConditionEvaluted.size() > 0){
            
            for(ID inputID : mapInputConditionEvaluted.keyset()){
                mapInputConditionEvalutedCounter.put(inputID,0);
            } 
        }
	    
    }
    
    public void updateSectionConditionEvaluted(){
    
        if(mapSectionConditionEvaluted.size() > 0 && mapSectionDisplayType.size() > 0){
    	        
	        for(Id sectionID : mapSectionConditionEvaluted.keyset()){
	            
	            if(mapSectionConditionEvaluted.get(sectionID).isEmpty()){
	                mapSectionDisplayType.put(sectionID,'Show');
	            }
	            else{
	                for(List_Condition__c objLC : mapSectionConditionEvaluted.get(sectionID).keySet()) {
	                    
	                    if(objLC.Type__c == 'Hide' && mapSectionConditionEvaluted.get(sectionID).get(objLC) == True){
	                        mapSectionDisplayType.put(sectionID,'Hide');
	                    }
	                    else if(objLC.Type__c == 'Hide' && mapSectionConditionEvaluted.get(sectionID).get(objLC) == False){
	                        mapSectionDisplayType.put(sectionID,'Show');
	                    }
	                    else if(objLC.Type__c == 'Show' && mapSectionConditionEvaluted.get(sectionID).get(objLC) == False){
	                        mapSectionDisplayType.put(sectionID,'Hide');
	                    }
	                    else if(objLC.Type__c == 'Show' && mapSectionConditionEvaluted.get(sectionID).get(objLC) == True){
	                        mapSectionDisplayType.put(sectionID,'Show');
	                    }
	                    else{
	                        mapSectionDisplayType.put(sectionID,'Show');
	                    }
	                }
	            }
	        }
	    }
    }
    
    public void updateInputConditionEvaluted(){
        
        system.debug('==================IN updateInputConditionEvaluted=================');
        system.debug('==================mapInputConditionEvaluted=================' + mapInputConditionEvaluted);
        if(mapInputConditionEvaluted.size() > 0){

	        for(Id inputID : mapInputConditionEvaluted.keyset()){
	            
	            if(!mapInputConditionEvaluted.get(inputID).isEmpty()){
	                
	                system.debug('==================inputID=================' + inputID);
	                for(List_Condition__c objLC : mapInputConditionEvaluted.get(inputID).keySet()) {
	                   
	                    system.debug('==================objLC.Type__c=================' + objLC.Type__c);
	                    system.debug('==================mapInputConditionEvaluted.get(inputID).get(objLC)=================' + mapInputConditionEvaluted.get(inputID).get(objLC));
	                    if(objLC.Type__c == 'Hide' && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).display = False;
	                    }
	                    else if(objLC.Type__c == 'Hide' && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).display = True;
	                    }
	                    else if(objLC.Type__c == 'Show' && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).display = False;
	                    }
	                    else if(objLC.Type__c == 'Show' && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).display = True;
	                    }
	                    else if(objLC.Type__c == 'Required' && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).required = True;
	                    }
	                    else if(objLC.Type__c == 'Required' && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).required = False;
	                    }
	                    else if(objLC.Type__c == 'Not Required' && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).required = True;
	                    }
	                    else if(objLC.Type__c == 'Not Required' && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).required = False;
	                    }
	                    else if(objLC.Type__c == 'Read Only' && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).readOnly = True;
	                    }
	                }
	            }
	        }
	    }
    }
    
    public void updateRefInputConditionEvaluted(map<Id,String> mapInputValues1){
        
        if(mapInputConditionEvaluted.size() > 0 && mapInputWrapper.size() > 0){
    	        
	        for(Id inputID : mapInputConditionEvaluted.keyset()){
	            
	            if(mapInputConditionEvaluted.containsKey(inputID) && !mapInputConditionEvaluted.get(inputID).isEmpty()){
	                
	                for(List_Condition__c objLC : mapInputConditionEvaluted.get(inputID).keySet()) 
	                {
	                    if(objLC.Type__c == 'Hide' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC) && mapInputConditionEvaluted.get(inputID).get(objLC) == True)
	                    {
	                        mapInputWrapper.get(inputID).display = False;
	                        if(recursionCall != null && mapRefreshData.containsKey(inputID)){
                                mapRefreshData.put(inputID,mapFormAllInputValues.get(inputID));
                            }
	                        system.debug('==========mapInputConditionEvalutedCounter.get(inputID)===========' + mapInputConditionEvalutedCounter.get(inputID));
	                        if(setRefCCInputIds.contains(inputID) && mapInputConditionEvalutedCounter.get(inputID) == 0){
	                             
	                            elementID = inputID;
	                            Map<Id,String> mapInputValuesRefresh = new Map<Id,String>();
	                            mapInputValuesRefresh = mapInputValues1.clone();
	                            mapInputValuesRefresh.put(inputID,'');
	                            recursionCall = True;
	                            mapInputConditionEvalutedCounter.put(inputID,1);
	                            
                                inputShowHideRefInput(mapInputValuesRefresh);
	                        }
	                    }
	                    else if(objLC.Type__c == 'Hide' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC) &&  mapInputConditionEvaluted.get(inputID).get(objLC) == False)
	                    {
	                        mapInputWrapper.get(inputID).display = True;
	                        
	                        if(setRefCCInputIds.contains(inputID) && mapInputConditionEvalutedCounter.get(inputID) == 0){
	                            
    	                        system.debug('==========When show mapRefreshData===========inputID==>>'+ inputID + '==>>' + mapRefreshData.get(inputID));
	                            elementID = inputID;
	                            Map<Id,String> mapInputValuesRefresh = new Map<Id,String>();
	                            mapInputValuesRefresh = mapInputValues1.clone();
	                            mapInputValuesRefresh.put(inputID,mapRefreshData.get(inputID));
	                            recursionCall = True;
	                            mapInputConditionEvalutedCounter.put(inputID,1);
                                inputShowHideRefInput(mapInputValuesRefresh);
	                        }
	                        system.debug('==========mapInputConditionEvalutedCounter.get(inputID)===========' + inputID + '===>>' + mapInputConditionEvalutedCounter.get(inputID));
	                    }
	                    else if(objLC.Type__c == 'Show' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC)  && mapInputConditionEvaluted.get(inputID).get(objLC) == False)
	                    {
	                        mapInputWrapper.get(inputID).display = False;
	                        if(recursionCall != null && mapRefreshData.containsKey(inputID)){
                                mapRefreshData.put(inputID,mapFormAllInputValues.get(inputID));
                            }
	                        system.debug('==========mapInputConditionEvalutedCounter.get(inputID)===========' + mapInputConditionEvalutedCounter.get(inputID));
	                        if(setRefCCInputIds.contains(inputID) && mapInputConditionEvalutedCounter.get(inputID) == 0){
	                            
	                            elementID = inputID;
	                            Map<Id,String> mapInputValuesRefresh = new Map<Id,String>();
	                            mapInputValuesRefresh = mapInputValues1.clone();
	                            mapInputValuesRefresh.put(inputID,'');
	                            recursionCall = True;
	                            mapInputConditionEvalutedCounter.put(inputID,1);
	                            
                                inputShowHideRefInput(mapInputValuesRefresh);
	                        }
	                       
	                    }
	                    else if(objLC.Type__c == 'Show' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC) && mapInputConditionEvaluted.get(inputID).get(objLC) == True)
	                    {
	                        mapInputWrapper.get(inputID).display = True;
	                        system.debug('==========mapInputConditionEvalutedCounter.get(inputID)===========' + mapInputConditionEvalutedCounter.get(inputID));
	                        if(setRefCCInputIds.contains(inputID) && mapInputConditionEvalutedCounter.get(inputID) == 0){
	                            
	                            system.debug('==========When show mapRefreshData===========inputID==>>'+ inputID + '==>>' + mapRefreshData.get(inputID));
	                            elementID = inputID;
	                            Map<Id,String> mapInputValuesRefresh = new Map<Id,String>();
	                            mapInputValuesRefresh = mapInputValues1.clone();
	                            mapInputValuesRefresh.put(inputID,mapRefreshData.get(inputID));
	                            recursionCall = True;
	                            mapInputConditionEvalutedCounter.put(inputID,1);
                                inputShowHideRefInput(mapInputValuesRefresh);
	                        }
	                    }
	                    else if(objLC.Type__c == 'Required' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC) && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).required = True;
	                    }
	                    else if(objLC.Type__c == 'Required' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC)  && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).required = False;
	                    }
	                    else if(objLC.Type__c == 'Not Required' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC)  && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).required = True;
	                    }
	                    else if(objLC.Type__c == 'Not Required' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC) && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).required = False;
	                    }
	                    else if(objLC.Type__c == 'Read Only' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC)  && mapInputConditionEvaluted.get(inputID).get(objLC) == True){
	                        mapInputWrapper.get(inputID).readOnly = True;
	                    }
	                    else if(objLC.Type__c == 'Read Only' && mapInputConditionEvaluted.containsKey(inputID) 
	                    && mapInputConditionEvaluted.get(inputID).containsKey(objLC)  && mapInputConditionEvaluted.get(inputID).get(objLC) == False){
	                        mapInputWrapper.get(inputID).readOnly = False;
	                    }
	                }
	            }
	        }
	    }
	    system.debug('==========updateRefInputConditionEvaluted mapInputConditionEvaluted size' + mapInputConditionEvaluted.size());
    }
    
    //Wrapper class
    public class InputConditionWrapperClass {
        
        public Boolean display {get;set;}
        public Boolean required {get;set;}
        public Boolean readOnly {get;set;}
        
        public InputConditionWrapperClass(Boolean display,Boolean required,Boolean readOnly) {
            
            this.display = display;
            this.required = required;
            this.readOnly = readOnly;
        }        
    }
    
}