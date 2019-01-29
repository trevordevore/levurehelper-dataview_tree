script "DataView Tree IDE Helper Library"


/**
Summary: Creates a new DataView Tree after prompting the user for some options.

Parameters:
pTargetCard: A reference to the card to create the DataView on. Default is the current card of the topStack.

Description:

Returns:
it: The long id of the new control. Empty if an error occurs.
*/
command dvtIdecreateDataViewTreeControlUsingDialog pTargetCard
  local tError, tDialogA, tDataViewControl, tStyleTemplatesA

  if pTargetCard is empty then
    put the long id of the current card of the topStack into pTargetCard
  end if

  # Use dialogData to configure dialog settings
  put "parent,leaf" into tDialogA["default row template styles"]
  set the dialogData to tDialogA

  # Set default templates to use for row styles
  put the long id of group "Parent Row Template" of stack "DataViewTreeRowTemplates" into tStyleTemplatesA["parent"]
  put the long id of group "Leaf Row Template" of stack "DataViewTreeRowTemplates" into tStyleTemplatesA["leaf"]
  put tStyleTemplatesA["parent"] into tStyleTemplatesA["default"]

  dvIdeCreateDataViewControlUsingDialog pTargetCard, the long id of stack "DataView Tree Behavior", tStyleTemplatesA
  put it into tDataViewControl

  if tDataViewControl is not empty then
    set the uExpandedIconPath of tDataViewControl to "M1216 960L1216 832Q1216 806 1197 787 1178 768 1152 768L384 768Q358 768 339 787 320 806 320 832L320 960Q320 986 339 1005 358 1024 384 1024L1152 1024Q1178 1024 1197 1005 1216 986 1216 960ZM1536 896Q1536 1105 1433 1281.5 1330 1458 1153.5 1561 977 1664 768 1664 559 1664 382.5 1561 206 1458 103 1281.5 0 1105 0 896 0 687 103 510.5 206 334 382.5 231 559 128 768 128 977 128 1153.5 231 1330 334 1433 510.5 1536 687 1536 896Z"
    set the uCollapsedIconPath of tDataViewControl to "M1216 960L1216 832Q1216 806 1197 787 1178 768 1152 768L896 768 896 512Q896 486 877 467 858 448 832 448L704 448Q678 448 659 467 640 486 640 512L640 768 384 768Q358 768 339 787 320 806 320 832L320 960Q320 986 339 1005 358 1024 384 1024L640 1024 640 1280Q640 1306 659 1325 678 1344 704 1344L832 1344Q858 1344 877 1325 896 1306 896 1280L896 1024 1152 1024Q1178 1024 1197 1005 1216 986 1216 960ZM1536 896Q1536 1105 1433 1281.5 1330 1458 1153.5 1561 977 1664 768 1664 559 1664 382.5 1561 206 1458 103 1281.5 0 1105 0 896 0 687 103 510.5 206 334 382.5 231 559 128 768 128 977 128 1153.5 231 1330 334 1433 510.5 1536 687 1536 896Z"
    return tDataViewControl for value
  else
    return empty for error
  end if
end dvtIdecreateDataViewTreeControlUsingDialog
