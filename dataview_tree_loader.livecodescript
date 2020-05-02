script "DataView Tree Assets Loader"

/**
Summary: Used to load the DataView Tree in non-Levure applications.

Description:
Levure applications will load a DataView as a helper and automatically handles
the loading process. This script will do everything manually.

*/
on libraryStack
  if the target is not me then pass libraryStack

  local tParentFolder
  local tStackFile

  put _parentFolder() into tParentFolder

  repeat for each item tStackFile in "dataview_tree"
    get there is a stack (tParentFolder & "/" & tStackFile & ".livecodescript")
  end repeat

  get there is a stack (tParentFolder & "/" & "dataview.livecode")

  if the environment is "development" then
    get there is a stack (tParentFolder & "/" & "ide/row_templates.livecode")
    start using stack (tParentFolder & "/" & "ide/ide_library.livecodescript")
  end if

  load extension from file (tParentFolder & "/" & "tree_lines.lcm")

  send "__removeDataViewTreeLoaderFromMemory" to stack "DataView Tree Behavior" in 0 seconds

  stop using me
end libraryStack


command __removeDataViewTreeLoaderFromMemory
  delete me
end __removeDataViewTreeLoaderFromMemory


private function _parentFolder
  local tFilename
  set the itemdelimiter to "/"
  put the filename of me into tFilename
  return item 1 to -2 of tFilename
end _parentFolder
