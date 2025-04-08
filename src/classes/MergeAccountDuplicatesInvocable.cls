/*
 * @Description - Invocable Apex Class to be called from Flow and that calls MergeService class 
 * @Author - Luke Cushanick
*/
public without sharing class MergeAccountDuplicatesInvocable {
    @InvocableMethod(label='Send Duplicate Record Items' description='.' category= 'Duplicate Record Item')
    public static void buildMergeMap(List<DuplicateRecordItem> dupeItems) {
        //Add all DuplicateRecordSets related to the list of DuplicateRecordItems to a Map(Id, List<Id>) so we can...        
        try{
            List<DuplicateRecordItem> mergeDeleteList = new List<DuplicateRecordItem>();
            Set<Id> dupeSetsSet = new Set<Id>();

            for(DuplicateRecordItem dupeItem : dupeItems){
                dupeSetsSet.add(dupeItem.DuplicateRecordSetId);
            }

            //...get related DuplicateRecordItems that were not updated in the current transaction 

            List<DuplicateRecordItem> getDRIs = [SELECT Id, DuplicateRecordSetId, RecordId, Merge_Decision__c FROM DuplicateRecordItem WHERE DuplicateRecordSetId IN :dupeSetsSet];

            //Iterate DRIs that have Merge and Keep and add to the Map; the 1st item in a List becomes the master record in MergeService.cls; add other DRIs to new List            
                Map<Id,List<Id>> mergeMap = new Map<Id,List<Id>>();
                for(DuplicateRecordItem dupeItem : getDRIs){
                if(dupeItem.Merge_Decision__c == 'Merge and Keep'){
                    if(mergeMap.containsKey(dupeItem.DuplicateRecordSetId)){
                        mergeMap.get(dupeItem.DuplicateRecordSetId).add(dupeItem.RecordId);

                    } else {
                        mergeMap.put(dupeItem.DuplicateRecordSetId, new List<Id>{dupeItem.RecordId});
                    }
                } else if(dupeItem.Merge_Decision__c == 'Merge and Delete'){
                    mergeDeleteList.add(dupeItem);
                }
            }

            System.debug('before:' + mergeMap);

            //Iterate the Map's Lists and remove any that have more than 1 item; we do not merge 2+ "Merge and Keep" records.
            for(Id keepListId : mergeMap.keySet()){
                if(mergeMap.get(keepListId).size() > 1){
                    List<Id> tooManyKeepers = mergeMap.remove(keepListId);
                }
            }

            System.debug('after:' + mergeMap);

            //Iterate all DRIs that have "Merge and Delete" and only add to Map's List<Id> if the DRS Id exists already; 
                //this ensures that we only attempt merges on records that have a "Merge and Keep" duplicate
            for(DuplicateRecordItem mergeItem : mergeDeleteList){
                if(mergeMap.containsKey(mergeItem.DuplicateRecordSetId)){
                    mergeMap.get(mergeItem.DuplicateRecordSetId).add(mergeItem.RecordId);
                }

            }
            System.debug('end:' + mergeMap);
            
            if(mergeMap.values().size() > 0){
                MergeService.getInstance('Account').mergeMany(mergeMap.values());
            }

        }
        catch(Exception ex) {
        }

    }
}
