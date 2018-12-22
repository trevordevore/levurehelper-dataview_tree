script "DataView Tree Behavior" with behavior "DataView Group Behavior"
/**
Summary: Toggles the exanded state of a row.

Parameters:
xDataSetA: The data set containing the tree that is displayed in the DataView. Values in this array will be updated.
pRow: The row to toggle.
pLevelsDown: How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
pExpandedState: Pass in a true/false to force a setting.

Returns: The new row number of pRow after the toggle.
*/
command TreeToggleRow @xDataSetA, pRow, pLevelsDown, pExpandedState
  local tSelElementKeys, tElementKey
  local tCurrentLevel, tChildNodes, tItemNo
  local i

  set the wholematches to true

  # store selected elements
  put the dvHilitedRows of me into tSelElementKeys
  repeat with i = 1 to the number of items of tSelElementKeys
    put item (item i of tSelElementKeys) of xDataSetA["visible nodes"] into item i of tSelElementKeys
  end repeat

  if pLevelsDown is empty then
    put 0 into pLevelsDown
  else if pLevelsDown < 0 then
    put -1 into pLevelsDown
  end if

  # Make sure node is visible
  put item pRow of xDataSetA["visible nodes"] into tElementKey
  _ShowNode xDataSetA, tElementKey

  # Toggle
  _SetExpandedState xDataSetA, pRow, pExpandedState

  # Affect children
  if pLevelsDown is not 0 then
    put 0 into tCurrentLevel
    _SetNodeAncestorExpandedState xDataSetA, tElementKey, xDataSetA["nodes"][tElementKey]["expanded"], \
          pLevelsDown, tCurrentLevel
  end if

  lock screen

  --   put the milliseconds into theStart

  RenderView

  --   put "time:" && the milliseconds - theStart

  put TreeDescendantNodesOfRow(xDataSetA, pRow, true) into tChildNodes
  if tChildNodes is not empty then
    local tLastRow

    put itemOffset(the last item of tChildNodes, xDataSetA["visible nodes"]) into tLastRow
    ScrollRowIntoView tLastRow, "bottom"
  end if

  # Now make sure pRow is visible
  ScrollRowIntoView pRow, "top" # scroll to top if not in view

  # update selected rows
  # rows may no longer be available because they are contracted
  if tSelElementKeys is not empty then
    repeat with i = the number of items of tSelElementKeys down to 1
      put itemOffset(item i of tSelElementKeys, xDataSetA["visible nodes"]) into tItemNo
      if tItemNo > 0 then
        put tItemNo into item i of tSelElementKeys
      else
        delete item i of tSelElementKeys
      end if
    end repeat

    # If there are no rows left to be selected then select row that was toggled
    if tSelElementKeys is empty then put pRow into tSelElementKeys
    set the dvHilitedRows of me to tSelElementKeys
  end if

  unlock screen

  return itemOffset(tElementKey, xDataSetA["visible nodes"])
end TreeToggleRow


/**
Summary: Sets the expanded state for a node.

Parameters:
@xDataSetA The data set containing the tree.
pRow: The row to expand/contract.
pBoolean: The value to assign to the expanded state. Leave empty to toggle.

Returns: empty
*/
private command _SetExpandedState @xDataSetA, pRow, pBoolean
  local theChildElementKeys, theChildElementKey, theElementKey, theItemCount

  put item pRow of xDataSetA["visible nodes"] into theElementKey

  if pBoolean is empty then put not xDataSetA["nodes"][theElementKey]["expanded"] into pBoolean
  else put pBoolean is true into pBoolean

  # Make sure it has a boolean value
  if xDataSetA["nodes"][theElementKey]["expanded"] is empty then \
        put false into xDataSetA["nodes"][theElementKey]["expanded"]

  if xDataSetA["nodes"][theElementKey]["expanded"] is not pBoolean then
    if not xDataSetA["nodes"][theElementKey]["is leaf"] then
      if xDataSetA["nodes"][theElementKey]["children"] is not empty then
        if not pBoolean then
          put _NumberOfVisibleAncestors(xDataSetA, "nodes", theElementKey) into theItemCount
          delete item (pRow + 1) to (pRow + theItemCount) of xDataSetA["visible nodes"]
          put false into xDataSetA["nodes"][theElementKey]["expanded"]
        else
          put true into xDataSetA["nodes"][theElementKey]["expanded"]
          put _DescendantElements(xDataSetA, "nodes", theElementKey, true) into theChildElementKeys

          # make sure we don't add children to visible nodes twice
          set the wholematches to true
          local theRow
          put pRow into theRow
          repeat for each item theChildElementKey in theChildElementKeys
            if theChildElementKey is not among the items of xDataSetA["visible nodes"] then
              put "," & theChildElementKey after item theRow of xDataSetA["visible nodes"]
              add 1 to theRow
            end if
          end repeat
        end if
      end if
    end if
  end if

  return empty
end _SetExpandedState


/**
Summary: Expands any tree nodes necessary so that the node can be seen. The selected row(s) will be maintained.

Parameters:
xDataSetA: The data set containing the tree.
pElementKey: The key in the data set that should be shown.

Returns: The new row number of the node
*/
command TreeShowNode @xDataSetA, pElementKey
  local theSelElementKeys, theRow, i

  # store selected elements
  put the dvHilitedRows of me into theSelElementKeys
  put item 1 of theSelElementKeys into theRow
  repeat with i = 1 to the number of items of theSelElementKeys
    put item (item i of theSelElementKeys) of xDataSetA["visible nodes"] into item i of theSelElementKeys
  end repeat

  _ShowNode xDataSetA, pElementKey

  lock screen
  RenderView

  # update selected rows
  # rows may no longer be available because they are contracted
  if theSelElementKeys is not empty then
    local theItemNo

    set the wholematches to true
    repeat with i = the number of items of theSelElementKeys down to 1
      put itemOffset(item i of theSelElementKeys, xDataSetA["visible nodes"]) into theItemNo
      if theItemNo > 0 then
        put theItemNo into item i of theSelElementKeys
      else
        delete item i of theSelElementKeys
      end if
    end repeat

    # If there are no rows left to be selected then select row that was toggled
    if theSelElementKeys is empty then put itemOffset(pElementKey, xDataSetA["visible nodes"]) into theSelElementKeys
    set the dvHilitedRows of me to theSelElementKeys
  end if

  # Now make sure shown row is visible
  ScrollRowIntoView itemOffset(pElementKey, xDataSetA["visible nodes"])

  unlock screen

  set the wholematches to true
  return itemOffset(pElementKey, xDataSetA["visible nodes"])
end TreeShowNode


/**
Summary: Expands any tree nodes necessary so that the node can be seen.

Parameters:
xDataSetA: The data set containing the tree.
pElementKey: The key in the data set that should be shown.

Returns: empty
*/
private command _ShowNode @xDataSetA, pElementKey
  local theParentKey, theKeys

  # Build list from root parent down to pElementKey and then work through it.
  # We need this in order to expand a row.
  put xDataSetA["nodes"][pElementKey]["parent"] into theParentKey

  repeat until theParentKey is empty
    put theParentKey & "," after theKeys
    put xDataSetA["nodes"][theParentKey]["parent"] into theParentKey
  end repeat
  delete the last char of theKeys

  local theKey, theRowNo
  set the wholematches to true

  repeat with i = the number of items of theKeys down to 1
    put item i of theKeys into theKey
    if not xDataSetA["nodes"][theKey]["expanded"] then
      put itemOffset(theKey, xDataSetA["visible nodes"]) into theRowNo
      if theRowNo > 0 then
        _SetExpandedState xDataSetA, theRowNo, true
      end if
    end if
  end repeat

  return empty
end _ShowNode


/**
Summary: Returns the node keys of the ancestors of a row.

Parameters:
pDataSetA: The data set containing the tree.
pRow: The row to get ancestor nodes for.

Returns: List
*/
function TreeAncestorNodesOfRow pDataSetA, pRow
  local theElementKey
  put item pRow of pDataSetA["visible nodes"] into theElementKey
  return _AncestorElements(pDataSetA, "nodes", theElementKey)
end TreeAncestorNodesOfRow


/**
Summary: Returns the node keys of the ancestors of a node.

Parameters:
pDataSetA: The data set containing the tree.
pNodeKey: The node key to get ancestor nodes for.

Returns: List
*/
function TreeAncestorNodesOfNode pDataSetA, pNodeKey
  return _AncestorElements(pDataSetA, "nodes", pNodeKey)
end TreeAncestorNodesOfNode


/**
Summary: Returns the node keys of the descendants of a row.

Parameters:
pDataSetA: The data set containing the tree.
pRow: The row to get ancestor nodes for.
pOnlyVisible: Pass in true to only return the visible descendant elements of pElementKey. Default is false.

Returns: List
*/
function TreeDescendantNodesOfRow pDataSetA, pRow, pOnlyVisible
  local theElementKey
  put item pRow of pDataSetA["visible nodes"] into theElementKey
  return _DescendantElements(pDataSetA, "nodes", theElementKey, pOnlyVisible)
end TreeDescendantNodesOfRow


/**
Summary: Returns the node keys of the descendants of a node.

Parameters:
pDataSetA: The data set containing the tree.
pNodeKey: The node key to get ancestor nodes for.
pOnlyVisible: Pass in true to only return the visible descendant elements of pElementKey. Default is false.
*
* \package Tree

Returns: List
*/
function TreeDescendantNodesOfNode pDataSetA, pNodeKey, pOnlyVisible
  return _DescendantElements(pDataSetA, "nodes", pNodeKey, pOnlyVisible)
end TreeDescendantNodesOfNode


/**
Summary: Recursive helper command for expanding nodes.

Parameters:
@xDataSetA: The data set containing the tree.
pElementKey: The key in the data set that should be expanded.
pExpandedState: True or false.
pLevelsDown: The number of levels down to expand. Leave empty to expand all children.
@pCurrentLevel: The current level that is being expanded. When this matches pLevelsDown or the last child is expanded then recursion stops.

Returns: empty
*/
command _SetNodeAncestorExpandedState @xDataSetA, pElementKey, pExpandedState, pLevelsDown, @pCurrentLevel
  local theCurrentLevel, theChildrenKeys, theKey, theRowNo

  put pExpandedState is true into pExpandedState

  add 1 to theCurrentLevel
  put pCurrentLevel into theCurrentLevel

  put xDataSetA["nodes"][pElementKey]["children"] into theChildrenKeys

  set the wholematches to true

  repeat for each item theKey in theChildrenKeys
    if xDataSetA["nodes"][theKey]["expanded"] is not pExpandedState then
      put itemOffset(theKey, xDataSetA["visible nodes"]) into theRowNo
      if theRowNo > 0 then
        # Make call which deals with visible toggling
        _SetExpandedState xDataSetA, theRowNo, pExpandedState
      else
        put pExpandedState into xDataSetA["nodes"][theKey]["expanded"]
      end if
    end if

    if theCurrentLevel is not pLevelsDown then
      _SetNodeAncestorExpandedState xDataSetA, theKey, pExpandedState, pLevelsDown, pCurrentLevel
      put theCurrentLevel into pCurrentLevel # reset for next child in loop.
    end if
  end repeat

  return empty
end _SetNodeAncestorExpandedState


/**
Summary: Returns a list of nodes that are descendants of a node.

Parameters:
pDataSetA: The tree structure.
pNodesKey: The name of the nodes key.
pParentNodeId: The parent node id.
pOnlyVisible: Only get the visible ancestor ids.

Returns: List
*/
private function _DescendantElements pDataSetA, pNodesKey, pParentNodeId, pOnlyVisible
  local theIds, theChildId, theChildIds

  put pOnlyVisible is true into pOnlyVisible

  if not pOnlyVisible OR (pOnlyVisible AND pDataSetA[pNodesKey][pParentNodeId]["expanded"]) then
    repeat for each item theChildId in pDataSetA[pNodesKey][pParentNodeId]["children"]
      put theChildId into item (the number of items of theIds + 1) of theIds

      put _DescendantElements(pDataSetA, pNodesKey, theChildId, pOnlyVisible) into theChildIds
      if theChildIds is not empty then
        put theChildIds into item (the number of items of theIds + 1) of theIds
      end if
    end repeat
  end if

  return theIds
end _DescendantElements


/**
Summary: Returns a list of nodes that are ancestors of a node.

Parameters:
pDataSetA:The tree structure.
pNodesKey: The name of the nodes key.
pChildNodeId: The child node id to get the ancestors for.

Returns: List
*/
private function _AncestorElements pDataSetA, pNodesKey, pChildNodeId
  local theIds, theAncestorIds

  if pDataSetA[pNodesKey][pChildNodeId]["parent"] is not empty then
    put pDataSetA[pNodesKey][pChildNodeId]["parent"] into theIds
    put _AncestorElements(pDataSetA, pNodesKey, pDataSetA[pNodesKey][pChildNodeId]["parent"]) into theAncestorIds
    if theAncestorIds is not empty then
      put "," & theAncestorIds after theIds
    end if
  end if

  return theIds
end _AncestorElements


/**
Summary: Returns the number of visible ancestor nodes of a node.

Parameters:
pDataSetA: The tree structure.
pNodesKey: The name of the nodes key.
pParentNodeId: The parent node id.

Returns: Integer
*/
private function _NumberOfVisibleAncestors pDataSetA, pNodesKey, pParentNodeId
  local theItemCount, theChildId

  if pDataSetA[pNodesKey][pParentNodeId]["expanded"] then
    put the number of items of pDataSetA[pNodesKey][pParentNodeId]["children"] into theItemCount

    repeat for each item theChildId in pDataSetA[pNodesKey][pParentNodeId]["children"]
      add _NumberOfVisibleAncestors(pDataSetA, pNodesKey, theChildId) to theItemCount
    end repeat
  end if

  return max(theItemCount, 0)
end _NumberOfVisibleAncestors


/**
Summary: Locates an element in the tree (representation of a row). The element may or may not be a visible row.

Parameters:
pDataSetA: The data set to search.
pKey: The name of the key to use to locate the row.
pValue: The value to find.

Description:
You can pass in multiple pairs of key/value parameters in order to match multiple keys.

Alternatively you can pass in an array for `pKey`. The keys of the array are
keys to search for and the value of each key is the value the key will match on.

An array with `key`, `row` and `visible` keys will be returned.
`key` is the key of the node found under the `nodes` key in `pDataSetA`.
`key` will be empty if not found.

Example


Returns: Array
*/
function TreeFindNode pDataSetA, pKey, pValue
  local i, foundAMatch, theElementKey, theFilterA

  ## Create a lookup array
  if pKey is not an array then
    repeat with i = 2 to the paramCount
      put param(i+1) into theFilterA[param(i)]
      add 1 to i
    end repeat
  else
    put pKey into theFilterA
  end if

  # Find match
  repeat with i = 1 to the number of elements of pDataSetA[tNodesKey]
    put true into foundAMatch

    repeat for each key theKey in theFilterA
      if pDataSetA["nodes"][i][theKey] is not theFilterA[theKey] then
        put false into foundAMatch
        next repeat
      end if
    end repeat

    if foundAMatch then
      put i into theElementKey
      exit repeat
    end if
  end repeat

  # Fill in return value
  local theA
  put theElementKey into theA["key"]
  put true into theA["visible"]
  put empty into theA["row"]

  if theElementKey is not empty then
    set the wholematches to true
    put itemoffset(theElementKey, pDataSetA["visible nodes"]) into theA["row"]
    put theA["row"] > 0 into theA["visible"]
  end if

  return theA
end TreeFindNode


/**
Summary: Returns the order of a row in relation to its immediate siblings.

Parameters:
pDataSetA: A reference to the view data set.
pRow: The row to focus on. Must be visible.

Returns: Row number. Empty if no parent.
*/
function TreeRowPositionRelativeToParent pDataSetA, pRow
  local theId, theParentId, thePosition

  set the wholeMatches to true

  # Find position relative to parent.
  put item pRow of pDataSetA["visible nodes"] into theId
  put pDataSetA["nodes"][theId]["parent"] into theParentId

  if theParentId is not empty then
    return itemOffset(theId, pDataSetA["nodes"][theParentId]["children"])
  else
    local theRow

    ## At root level
    repeat for each item theId in pDataSetA["visible nodes"]
      add 1 to theRow
      if pDataSetA["nodes"][theId]["parent"] is empty then
        add 1 to thePosition
      end if
      if theRow is pRow then
        return thePosition
      end if
    end repeat
  end if

  return empty
end TreeRowPositionRelativeToParent


/**
Summary: Returns the tree level of a row.

Parameters:
pDataSetA: A reference to the view data set.
pElementKey: The key of the element to determine the level of.

Returns: Integer
*/
function TreeLevelOfNode pDataSetA, pElementKey
  local theLevel = "1"

  repeat until pDataSetA["nodes"][pElementKey]["parent"] is empty
    add 1 to theLevel
    put pDataSetA["nodes"][pElementKey]["parent"] into pElementKey
  end repeat

  return theLevel
end TreeLevelOfNode
