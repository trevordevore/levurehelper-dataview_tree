script "DataView Tree Behavior" with behavior "DataView Behavior"
constant kBuiltInProperties = "id,type,expanded,is leaf,children,level,child count"

local sTreeA
local sNodeIdNodeLookupA # key = node id, value = node index array in sTreeA
local sRowNodeIdLookupA # key = row, value = node id. Lookup in sNodeIdNodeLookupA.
local sNodeIdRowLookupA # key = node id, value = row number
local sRebuildLookupTable = false
local sDropInfoA

/**
Summary: Sets the tree used to display source tree data.

Parameters:
pRender: By default the tree will render when setting this property. Pass in false to not render the DataView.
pTreeA: An array representing tree used to draw the tree in the DataView.

Description:
The DataView uses an array that is populated with node arrays. A node array has
the following format:

```
pNodeA[type|id|expanded|children|is leaf]
```

A node can have other nodes as `children`.

A tree is made up of a `root` node with a `children` key that contains
one or more nodes.

```
pTreeA[root][children][1][type|id|expanded|children|is leaf]
pTreeA[root][children][n][type|id|expanded|children|is leaf]
```

Here is an example of a tree with three nodes – one node at the root, one node
as a child of the root node, and one node as the child of the child of the root node.

```
pTreeA["root"]["children"][1]["type"]
pTreeA["root"]["children"][1]["id"]
pTreeA["root"]["children"][1]["expanded"]
pTreeA["root"]["children"][1]["is leaf"]
pTreeA["root"]["children"][1]["children"]
pTreeA["root"]["children"][1]["children"][1]["type"]
pTreeA["root"]["children"][1]["children"][1]["id"]
pTreeA["root"]["children"][1]["children"][1]["expanded"]
pTreeA["root"]["children"][1]["children"][1]["is leaf"]
pTreeA["root"]["children"][1]["children"][1]["children"]
pTreeA["root"]["children"][1]["children"][1]["children"][1]["type"]
pTreeA["root"]["children"][1]["children"][1]["children"][1]["id"]
pTreeA["root"]["children"][1]["children"][1]["children"][1]["expanded"]
pTreeA["root"]["children"][1]["children"][1]["children"][1]["is leaf"]
pTreeA["root"]["children"][1]["children"][1]["children"][1]["children"]
```

At a minimum you should define the `type` and `id` properties for each node.
`id` should uniquely identify the node in the entire tree. `type` is used to
distinguish nodes from each other.
`expanded` is a boolean value and defaults to `false` if no value is present.

When setting the `dvTree` you can leave off the `["root"]["children"]` keys and pass
in a numerically indexed array of nodes. The array you pass in will be assigned to the
`["root"]["children"]` array internally.

Returns: nothing
*/
setProp dvTree[pRender] pTreeA
  put pRender is not false into pRender

  if "root" is among the keys of pTreeA then
    put pTreeA into sTreeA
  else
    put pTreeA into sTreeA["root"]["children"]
  end if

  _buildRowToNodeLookup
  put false into sRebuildLookupTable

  if pRender then
    lock screen
    ResetView
    RenderView
    unlock screen
  end if
end dvTree


/**
Summary: Returns the internal tree array.

Returns: Array
*/
getProp dvTree
  return sTreeA
end dvTree


/**
Summary: Returns all node ids in the tree in no particular order.

Description:
This property is useful if you need to look at all of the nodes in a tree
but in no particular order.

Returns: Comma delimited list
*/
getProp dvNodeIds
  local tKeys

  if sRebuildLookupTable then
    _buildRowToNodeLookup
    put false into sRebuildLookupTable
  end if

  put the keys of sNodeIdNodeLookupA into tKeys
  replace cr with comma in tKeys
  return tKeys
end dvNodeIds


/**
Summary: Adds a node to the tree and marks affected rows as dirty within the DataView.

Parameters:
pNode: An array representing the new node.
pParent: The node id of the parent node.
pPosition: The position within the parent's children. If empty then it will be the last sibling.
pRefreshView: Pass in false to prevent the view being refreshed.

Returns: nothing
*/
command AddNode pNodeA, pParent, pPosition, pRefreshView
  local tDirtyIdsA, tId

  put pRefreshView is not false into pRefreshView

  if pParent is empty then
    put "root" into pParent[1]
  else if pParent is not an array then
    put _findNodeOfId(pParent) into pParent
  end if

  _addNodeToParent pNodeA, pParent, pPosition, tDirtyIdsA

  repeat for each key tId in tDirtyIdsA
    _setNodeRowIsDirty tId, true
  end repeat

  # Brute force
  put true into sRebuildLookupTable

  if pRefreshView then
    _refreshView
  end if

  return empty
end AddNode


/**
Summary: Moves a node to a new position within the tree and marks affected rows as dirty within the DataView.

Parameters:
pNode: Node id.
pParent: New node parent id. Empty value assumes current parent.
pPosition: New position.
pRefreshView: Pass in false to prevent the view being refreshed.

Returns: nothing
*/
command MoveNode pNode, pParent, pPosition, pRefreshView
  local tCurrentParent, tDirtyIdsA, tId

  put pRefreshView is not false into pRefreshView

  if pNode is not an array then put _findNodeOfId(pNode) into pNode
  put _parentNodeIndex(pNode) into tCurrentParent

  if pParent is empty then put tCurrentParent into pParent
  else if pParent is not an array then put _findNodeOfId(pParent) into pParent

  if pParent is tCurrentParent then
    _moveNodeWithinParent pNode, pParent, pPosition, tDirtyIdsA
  else
    _moveNodeToNewParent pNode, pParent, pPosition, tDirtyIdsA
  end if

  repeat for each key tId in tDirtyIdsA
    _setNodeRowIsDirty tId, true
  end repeat

  # Brute force
  put true into sRebuildLookupTable

  if pRefreshView then
    _refreshView
  end if

  return empty
end MoveNode


/**
Summary: Deletes a node (and any children) from the tree.

Parameters:
pNodeIds: Comma delimited list of node ids.
pRefreshView: Pass in false to prevent the view being refreshed.

Returns: nothing
*/
command DeleteNodes pNodeIds, pRefreshView
  local tDirtyIdsA, tNodeA, tId

  put pRefreshView is not false into pRefreshView

  repeat for each item tId in pNodeIds
    put _findNodeOfId(tId) into tNodeA
    if tNodeA is an array then
      _deleteNode tNodeA, tDirtyIdsA
    end if
  end repeat

  repeat for each key tId in tDirtyIdsA
    _setNodeRowIsDirty tId, true
  end repeat

  # Brute force
  put true into sRebuildLookupTable

  if pRefreshView then
    _refreshView
  end if

  return empty
end DeleteNodes


/**
Summary: Adds a node to a parent.

Parameters:
pNodeA: Node array to add to parent.
pParent: Parent index lookup array.
pPosition: Position within parent.
rDirtyIdsA: Array whose keys are ids that are dirty after this handler completes.

Returns: nothing
*/
private command _addNodeToParent pNodeA, pParent, pPosition, @rDirtyIdsA
  local tChildrenA, tOldChildCount

  put the number of elements of sTreeA[pParent]["children"] into tOldChildCount

  if pPosition is empty then
    put tOldChildCount + 1 into pPosition
  end if

  if sTreeA[pParent]["children"][pPosition] is an array then
    local i

    repeat with i = tOldChildCount down to pPosition
      put sTreeA[pParent]["children"][i] into sTreeA[pParent]["children"][i+1]
      _updateNodeIndexInLookupTable sTreeA[pParent]["children"][i]["id"], i+1
    end repeat
  end if

  put pNodeA into sTreeA[pParent]["children"][pPosition]


  //////////
  // Mark any rows that need to change UI based on addition as dirty
  //////////

  // This may not exist in tree yet. _setNodeRowIsDirty performs checks though.
  put empty into rDirtyIdsA[ pNodeA["id"] ]

  // If 1st sibling was shifted down then it is dirty
  if pPosition is 1 and tOldChildCount > 0 then
    put empty into rDirtyIdsA[ sTreeA[pParent]["children"][2]["id"] ]
  end if

  if pPosition is tOldChildCount+1 then
    // previous sibling is dirty as it was previously the last child
    put empty into rDirtyIdsA[ sTreeA[pParent]["children"][tOldChildCount]["id"] ]
  end if

  if tOldChildCount is 0 then
    // parent is dirty as it now has children
    put empty into rDirtyIdsA[ sTreeA[pParent]["id"] ]
  end if
end _addNodeToParent


/**
Summary: Moves a node to a new parent.

Parameters:
pNode: Node lookup array.
pCurrentParent: Current parent index lookup array.
pNewParent: New parent index lookup array.
pPosition: Position within the new parent.
rDirtyIdsA: Array whose keys are ids that are dirty after this handler completes.

Returns: nothing
*/
private command _moveNodeToNewParent pNode, pNewParent, pPosition, @rDirtyIdsA
  local tNodeA

  put min(max(1, pPosition), the number of elements of sTreeA[pNewParent]["children"]+1) into pPosition

  // Store copy of node
  put sTreeA[pNode] into tNodeA

  // Delete node
  _deleteNode pNode, rDirtyIdsA

  // Move to new parent
  _addNodeToParent tNodeA, pNewParent, pPosition, rDirtyIdsA
end _moveNodeToNewParent


/**
Summary: Deletes a node from the tree and marks affected rows as dirty.

Parameters:
pNode: Node index lookup array.
xDirtyIdsA: Array whose keys are ids that are dirty after this handler completes.

Returns: nothing
*/
private command _deleteNode pNode, @xDirtyIdsA
  local tParent, tCurPosition, tChildCount, i

  put _parentNodeIndex(pNode) into tParent
  put the number of elements of sTreeA[tParent]["children"] into tChildCount
  put _nodePosition(pNode) into tCurPosition

  # Delete control if caching is turned on
  if the viewProp["cache"] of me is not "none" then
    DeleteRowControlFromCache sNodeIdRowLookupA[ sTreeA[pNode]["id"] ]
  end if

  # Remove all affected nodes from the lookup tables so non-existent index paths
  # aren't returned in calls to _findNodeOfId(). The lookup tables will be rebuilt
  # after calls to this handler.
  _removeNodeFromLookupTables pNode

  delete local sTreeA[pNode]

  // Adjust siblings
  repeat with i = tCurPosition+1 to tChildCount
    put sTreeA[tParent]["children"][i] into sTreeA[tParent]["children"][i-1]
    _updateNodeIndexInLookupTable sTreeA[tParent]["children"][i]["id"], i-1
  end repeat

  // Delete last sibling which is no longer valid
  if sTreeA[tParent]["children"][tChildCount] is an array then
    delete local sTreeA[tParent]["children"][tChildCount]
  end if

  //////////
  // Mark any rows that need to change UI based on addition as dirty
  //////////

  // If first sibling was affected then it is dirty
  if tCurPosition is 1 then
    put empty into xDirtyIdsA[ sTreeA[tParent]["children"][1]["id"] ]
  end if

  // If last sibling was affected then it is dirty
  if tCurPosition is tChildCount then
    put empty into xDirtyIdsA[ sTreeA[tParent]["children"][tChildCount-1]["id"] ]
  end if

  // If last child was deleted then mark parent as dirty
  if tChildCount is 1 then
    put empty into xDirtyIdsA[ sTreeA[tParent]["id"] ]
  end if
end _deleteNode


private command _updateNodeIndexInLookupTable pNodeId, pNewIndex
  local tIndexA

  put sNodeIdNodeLookupA[ pNodeId ] into tIndexA
  put pNewIndex into tIndexA[the number of elements of tIndexA]
  put tIndexA into sNodeIdNodeLookupA[ pNodeId ]
end _updateNodeIndexInLookupTable


private command _removeNodeFromLookupTables pNode
  local tRow, tIndexA, tIndexCount

  # Delete node in tables
  put sNodeIdRowLookupA[ sTreeA[pNode]["id"] ] into tRow
  delete local sRowNodeIdLookupA[ tRow ]
  delete local sNodeIdRowLookupA[ sTreeA[pNode]["id"] ]
  delete local sNodeIdNodeLookupA[ sTreeA[pNode]["id"] ]

  # Delete node children
  put the number of elements of pNode into tIndexCount
  put pNode into tIndexA

  repeat with tIndex = 1 to the number of elements of sTreeA[pNode]["children"]
    put "children" into tIndexA[tIndexCount + 1]
    put tIndex into tIndexA[tIndexCount + 2]

    _removeNodeFromLookupTables tIndexA
  end repeat
end _removeNodeFromLookupTables


/**
Summary: Moves a node within current parent and marks affected rows as dirty.

Parameters:
pNode: Node lookup array.
pParent: Parent index lookup array.
pPosition: Position within the new parent.
rDirtyIdsA: Array whose keys are ids that are dirty.

Returns: nothing
*/
private command _moveNodeWithinParent pNode, pParent, pPosition, @rDirtyIdsA
  local tChildCount, tCurPosition, i
  local tNodeA

  put the number of elements of sTreeA[pParent]["children"] into tChildCount
  put min(max(1, pPosition), tChildCount) into pPosition
  put _nodePosition(pNode) into tCurPosition

  if tCurPosition is pPosition then
    return empty
  end if

  put sTreeA[pNode] into tNodeA

  if tCurPosition < pPosition then
    -- t 1
    --   2 ^
    --   3 ^
    -- > 4 ^
    --   5
    repeat with i = tCurPosition+1 to pPosition
      put sTreeA[pParent]["children"][i] into sTreeA[pParent]["children"][i-1]
      _updateNodeIndexInLookupTable sTreeA[pParent]["children"][i]["id"], i-1
    end repeat
  else if tCurPosition > pPosition then
    -- > 1 v
    --   2 v
    --   3 v
    -- t 4
    --   5
    repeat with i = tCurPosition-1 down to pPosition
      put sTreeA[pParent]["children"][i] into sTreeA[pParent]["children"][i+1]
      _updateNodeIndexInLookupTable sTreeA[pParent]["children"][i]["id"], i+1
    end repeat
  end if

  put tNodeA into sTreeA[pParent]["children"][pPosition]


  //////////
  // Mark any rows that need to change UI based on addition as dirty
  //////////

  // If last sibling was affected then it is dirty
  if tCurPosition is tChildCount or pPosition is tChildCount then
    put empty into rDirtyIdsA[ sTreeA[pParent]["children"][tChildCount]["id"] ]
  end if

  // If first sibling was affected then it is dirty
  if tCurPosition is 1 or pPosition is 1 then
    put empty into rDirtyIdsA[ sTreeA[pParent]["children"][1]["id"] ]
  end if
end _moveNodeWithinParent


/**
Summary: Build lookup tables so that `NumberOfRows` can return correct value.

Returns: nothing
*/
command RefreshViewRows
  if sRebuildLookupTable then
    _buildRowToNodeLookup
    put false into sRebuildLookupTable
  end if
  pass RefreshViewRows
end RefreshViewRows


/**
Summary: Build lookup tables so that `NumberOfRows` can return correct value.

Returns: nothing
*/
command RenderView
  if sRebuildLookupTable then
    _buildRowToNodeLookup
    put false into sRebuildLookupTable
  end if
  pass RenderView
end RenderView


command DataForRow pRow, @rData, @rTemplateStyle
  local tNodeA, tIndexA, tKey

  put sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] into tIndexA

  # id, type, expanded, is leaf, + any custom keys
  repeat for each key tKey in sTreeA[ tIndexA ]
    if tKey is "children" then next repeat
    put sTreeA[ tIndexA ][tKey] into tNodeA[tKey]
  end repeat

  put _nodeLevel(tIndexA) into tNodeA["level"]
  put the number of elements of sTreeA[ tIndexA ]["children"] into tNodeA["child count"]

  # Cache for future use
  put _nodeTreeLineStyles(tIndexA, tNodeA["level"]) into sTreeA[ tIndexA ]["tree line styles"]

  dispatch "DataForNode" with tNodeA, pRow, rData, rTemplateStyle
end DataForRow


function NumberOfRows
  return the number of elements of sRowNodeIdLookupA
end NumberOfRows


/**
Summary: Returns the cache key for a given row.

Description:
The Cache Key for each row is a combination of the `id` property and an
internal `@version` property. Whenever a property is changed in the node array
(e.g. the `expanded` state) then the node is marked as dirty and the `@version`
will be updated, thus changing the cache key for the row. When the cache key
changes the DataView will redraw the row with the latest data.

Returns: String
*/
function CacheKeyForRow pRow
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["id"]
end CacheKeyForRow


/**
Summary: Refreshes the view after toggling or showing nodes.

Description:
When calling handlers that toggle the expanded state of a node(s) the UI
is not updated. This allows you to update multiple nodes and redraw all at
once. Call this handler when you are ready to redraw the view.

Returns: nothing
*/
command RefreshView
  _refreshView
  return empty
end RefreshView


/**
Summary: Hide the treeline widget before creating the drag image for a row control.

Returns: nothing
*/
before PreDragImageSnapshot
  if there is a control "TreeLines" of the target then
    set the visible of control "TreeLines" of the target to false
  end if
end PreDragImageSnapshot


/**
Summary: Show the treeline widget after creating the drag image for a row control.

Returns: nothing
*/
before PostDragImageSnapshot
  if there is a control "TreeLines" of the target then
    set the visible of control "TreeLines" of the target to true
  end if
end PostDragImageSnapshot


/**
Summary: Expands all rows in the tree.

Description:
Call `RefreshView` to redraw the view.

Returns: nothing
*/
command ExpandAllNodes
  local tIndexA

  put "root" into tIndexA[1]
  put "children" into tIndexA[2]

  _setExpandedInTreeBranch sTreeA["root"]["children"], tIndexA, true
  put true into sRebuildLookupTable
  _refreshView
end ExpandAllNodes


/**
Summary: Contracts all rows in the tree.

Description:
Call `RefreshView` to redraw the view.

Returns: nothing
*/
command CollapseAllNodes
  local tIndexA

  put "root" into tIndexA[1]
  put "children" into tIndexA[2]

  _setExpandedInTreeBranch sTreeA["root"]["children"], tIndexA, false
  put true into sRebuildLookupTable
  _refreshView
end CollapseAllNodes


/**
Summary: Sets the expanded state of a row.

Parameters:
pRow: The row to toggle.
pLevelsDown: How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
pExpandedState: Pass in a true/false to force a setting.
pRefreshView: Pass in false to keep the view from being refreshed.

Description:
By default the DataView will be redrawn after calling this handler and the newly displayed
children nodes will be scrolled into view. If you pass in `false` for `pRefreshView`
then call `RefreshView` to redraw the view.

Returns: Nothing
*/
command SetRowIsExpanded pRow, pLevelsDown, pExpandedState, pRefreshView
  if pRow < 1 then throw "invalid row:" && pRow

  SetNodeIsExpanded sRowNodeIdLookupA[pRow], pLevelsDown, pExpandedState, pRefreshView

  return empty
end SetRowIsExpanded


/**
Summary: Sets the expanded state of a node.

Parameters:
pNode: The node `id` or the node index array.
pLevelsDown: How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
pExpandedState: Pass in a true/false to force a setting.
pRefreshView: Pass in `false` to keep the view from being refreshed.

Description:
Expands the target node, expanding ancestors if need be in order to show the
target node.

See `SetRowIsExpanded` for more information.

Returns: empty
*/
command SetNodeIsExpanded pNode, pLevelsDown, pExpandedState, pRefreshView
  local tRow, tCurrentLevel

  put pRefreshView is not false into pRefreshView

  if pNode is not an array then put sNodeIdNodeLookupA[pNode] into pNode

  if pNode is not an array then throw "invalid node id"
  if sTreeA[pNode]["is leaf"] then throw "cannot change expanded setting of a leaf node"

  if pLevelsDown is empty then
    put 0 into pLevelsDown
  else if pLevelsDown < 0 then
    put -1 into pLevelsDown
  end if

  if sRebuildLookupTable then
    _buildRowToNodeLookup
    put false into sRebuildLookupTable
  end if

  # Toggle
  _setNodeExpandedState pNode, pExpandedState

  # Affect children
  if pLevelsDown is not 0 then
    put 0 into tCurrentLevel
    _setNodeAncestorExpandedState pNode, sTreeA[pNode]["expanded"], \
          pLevelsDown, tCurrentLevel
  end if

  if pRefreshView then
    _refreshView
  end if

  return empty
end SetNodeIsExpanded


/**
Summary: Toggles the expanded state of a row.

Parameters:
pRow: The row to toggle.
pLevelsDown: How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
pRefreshView: Pass in false to keep the view from being refreshed.

Description:
See `SetRowIsExpanded`.

Returns the new expanded state.

Returns: Boolean
*/
command ToggleRowIsExpanded pRow, pLevelsDown, pRefreshView
  local tNodeIndexA, tExpandedState

  put sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] into tNodeIndexA
  put not sTreeA[tNodeIndexA]["expanded"] into tExpandedState

  SetRowIsExpanded pRow, pLevelsDown, tExpandedState, pRefreshView
  return tExpandedState for value
end ToggleRowIsExpanded


/**
Summary: Toggles the expanded state of a node.

Parameters:
pNode: The node `id` or the node index array.
pLevelsDown: How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
pRefreshView: Pass in false to keep the view from being refreshed.

Description:
See `SetRowIsExpanded`.

Returns the new expanded state.

Returns: Boolean
*/
command ToggleNodeIsExpanded pNode, pLevelsDown, pRefreshView
  local tExpandedState

  if pNode is not an array then put _findNodeOfId(pNode, true) into pNode

  put not sTreeA[pNode]["expanded"] into tExpandedState
  SetNodeIsExpanded pNode, pLevelsDown, tExpandedState, pRefreshView
  return tExpandedState for value
end ToggleNodeIsExpanded


/**
Summary: Expands any tree nodes necessary so that the node can be seen.

Parameters:
pNode: The node `id` or the node index array.
pRefreshView: Pass in false to keep the view from being refreshed.

Description:
By default the DataView will be redrawn after calling this handler and the node will
be scrolled into view. If you pass in `false` for `pRefreshView`
then call `RefreshView` to redraw the view and `ScrollRowIntoView` to scroll
the row into view.

Returns: empty
*/
command ShowNode pNode, pRefreshView
  if pNode is not an array then put sNodeIdNodeLookupA[pNode] into pNode
  _showNode pNode

  if pRefreshView then
    lock screen
    _refreshView
    ScrollRowIntoView _rowOfNode(pNode)
    unlock screen
  end if

  return empty
end ShowNode


/**
Summary: Scrolls a row and it's descendants into view.

Parameters:
pRow: The target row.

Description:
When expanding a row it may be desirable to scroll the newly exposed children
into view. This handler will scroll the descendants into view without pushing
pRow off the top.

Returns: nothing
*/
command ScrollRowDescendantsIntoView pRow
  local tDescendantsA, tRect, tHeight

  put the dvRectOfRow[pRow] of me into tRect
  add item 4 of tRect - item 2 of tRect to tHeight

  put _descendantElements(sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], true) into tDescendantsA
  if tDescendantsA is an array then
    repeat with i = 1 to the number of elements of tDescendantsA
      put the dvRectOfRow[ _rowOfNode(tDescendantsA[i]) ] of me into tRect
      add item 4 of tRect - item 2 of tRect to tHeight
    end repeat
  end if

  if tHeight > the viewProp["content window height"] of me then
    # Descendants are too tall. Scroll anchor row to top.
    ScrollRowIntoView pRow, "top"
  else
    # All descendants fit into view. Scroll last one to bottom.
    local tLastRow
    if tDescendantsA is an array then
      put _rowOfNode(tDescendantsA[the number of elements of tDescendantsA]) into tLastRow
    else
      put pRow into tLastRow
    end if
    ScrollRowIntoView tLastRow, "bottom"
  end if
end ScrollRowDescendantsIntoView


/**
Summary: See ScrollRowDescendantsIntoView/

Returns: nothing
*/
command ScrollNodeDescendantsIntoView pNode
  ScrollRowDescendantsIntoView _rowOfNode(pNode)
end ScrollNodeDescendantsIntoView


/**
Summary: Finds a node by `id` and returns the index array pointing to a node in the tree.

Parameters:
pNodeId: The `id` of the node.

Description:
The index array that is returned by this function can be used in other DataView Tree
handlers. Index array can be used by the LiveCode engine to find nested keys in a
LiveCode array.

An index array is a numerically indexed array that represents the keys pointing
to a specific key in a nested array. For a key that is not nested the index array
would have a single key. For a key that is nested three levels deep the index
array would have three keys.

Assume the following array:

```
tPersonA["name"]
tPersonA["children"]
tPersonA["children"][1]["name"]
tPersonA["children"][2]["name"]
tPersonA["children"][3]["name"]
```

The index array for the third child would be as follows:

```
put "children" into tIndexA[1]
put 3 into tIndexA[2]
```

To get the name of the third child you would use the following syntax:

```
put tPersonA[tIndexA]["name"] into tChildName
```

Returns: Index array
*/
getProp dvNodeOfId[pNodeId]
  return _findNodeOfId(pNodeId, false)
end dvNodeOfId


/**
Summary: Returns the row assigned to a node.

Parameters:
pNodeId: The node id to search for.

Description:
If no row is associated with the id passed in then 0 is returned.
A valid id will not have a row if it is the descendant of an
ancestor that is not expanded.

Returns: Integer
*/
getProp dvRowOfId[pNodeId]
  return _rowOfNode(pNodeId)
end dvRowOfId


/**
Summary: Returns the node index array of the node associated with a row.

Returns: Array
*/
getProp dvRowNode[pRow]
  return sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]]
end dvRowNode


/**
Summary: Returns the `id` of the row's node.

Parameters:
pRow: The target row

Returns: Mixed
*/
getProp dvRowId[pRow]
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["id"]
end dvRowId


/**
Summary: Sets the `type` of a row.

Parameters:
pRow: The target row.
pType: The type.

Description:
Setting this property will not refresh the DataView.
*/
setProp dvRowType[pRow] pType
  _setNodeProperty sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], "type", pType
end dvRowType


/**
Summary: Returns the `type` of the row's node.

Parameters:
pRow: The target row

Returns: Mixed
*/
getProp dvRowType[pRow]
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["type"]
end dvRowType


/**
Summary: Returns the control associated with a node.

Parameters:
pNodeId: The target node id.

Returns: Control reference or empty
*/
getProp dvControlOfNode[pNodeId]
  return the dvControlOfRow[ sNodeIdRowLookupA[pNodeId] ] of me
end dvControlOfNode


/**
Summary: Sets the `type` of a node.

Parameters:
pNodeId: The target node id.
pType: The type.

Description:
Setting this property will not refresh the DataView.
*/
setProp dvNodeType[pNodeId] pType
  _setNodeProperty pNodeId, "type", pType
end dvNodeType


/**
Summary: Returns the `type` of the node.

Parameters:
pNode: The target node id

Returns: Value
*/
getProp dvNodeType[pNodeId]
  return _getNodeProperty(pNodeId, "type")
end dvNodeType


/**
Summary: Returns the `expanded` property of the row's node.

Parameters:
pRow: The target row

Returns: Boolean
*/
getProp dvRowIsExpanded[pRow]
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["expanded"]
end dvRowIsExpanded


/**
Summary: Expands the target row.

Parameters:
pRow: The target row
pIsExpanded: Boolean value.

Description:
For more options when expanding a row see `SetRowIsExpanded`.
*/
setProp dvRowIsExpanded[pRow] pIsExpanded
  SetRowIsExpanded pRow, 0, pIsExpanded is true, true
end dvRowIsExpanded


/**
Summary: Returns the `expanded` property of the node.

Parameters:
pNode: The target node id.

Returns: Boolean
*/
getProp dvNodeIsExpanded[pNodeId]
  return _getNodeProperty(pNodeId, "expanded")
end dvNodeIsExpanded


/**
Summary: Expands the target node.

Parameters:
pRow: The target row
pIsExpanded: Boolean value.

Description:
Setting this property will not refresh the DataView.

For more options when expanding a row see `SetNodeIsExpanded`.
*/
setProp dvNodeIsExpanded[pNodeId] pIsExpanded
  SetNodeIsExpanded pNodeId, 0, pIsExpanded is true, true
end dvNodeIsExpanded


/**
Summary: Sets the `is leaf` of a row.

Parameters:
pRow: The target row.
pIsLeaf: Boolean.

Description:
Setting this property will not refresh the DataView.
*/
setProp dvRowIsLeaf[pRow] pIsLeaf
  _setNodeProperty sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], "is leaf", pIsLeaf
end dvRowIsLeaf


/**
Summary: Returns the `is leaf` property of the row's node.

Parameters:
pRow: The target row

Returns: Boolean
*/
getProp dvRowIsLeaf[pRow]
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["is leaf"]
end dvRowIsLeaf


/**
Summary: Sets the `is leaf` of a node.

Parameters:
pNodeId: The target node id.
pIsLeaf: Boolean.

Description:
Setting this property will not refresh the DataView.
*/
setProp dvNodeIsLeaf[pNodeId] pIsLeaf
  _setNodeProperty pNodeId, "is leaf", pIsLeaf
end dvNodeIsLeaf


/**
Summary: Returns the `is leaf` property of the node.

Parameters:
pNode: The target node id.

Returns: Boolean
*/
getProp dvNodeIsLeaf[pNodeId]
  return _getNodeProperty(pNodeId, "is leaf")
end dvNodeIsLeaf


/**
Summary: Returns a numerically indexed array of node arrays at the root of the tree.

Returns: Array
*/
getProp dvRootNodes
  return sTreeA["root"]["children"]
end dvRootNodes


/**
Summary: Returns the number of nodes at the root of the tree.

Returns: Integer
*/
getProp dvRootNodeCount
  return the number of elements of sTreeA["root"]["children"]
end dvRootNodeCount


/**
Summary: Returns a list of ids at the root of the tree.

Returns: Comma-delimited list
*/
getProp dvRootNodeIds
  return _childrenIds(sTreeA["root"]["children"])
end dvRootNodeIds


/**
Summary: Returns the number of children that a row has.

Returns: Integer
*/
getProp dvRowChildCount[pRow]
  if not sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["is leaf"] then
    return the number of elements of sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["children"]
  else
    return 0
  end if
end dvRowChildCount


/**
Summary: Returns the number of children that a node has.

Returns: Integer
*/
getProp dvNodeChildCount[pNodeId]
  if not sTreeA[ sNodeIdNodeLookupA[pNodeId] ]["is leaf"] then
    return the number of elements of sTreeA[ sNodeIdNodeLookupA[pNodeId] ]["children"]
  else
    return 0
  end if
end dvNodeChildCount


/**
Summary: Sets the child nodes of a row.

Parameters:
pRow: The target row.
pNodesA: A numerically indexed array of child node arrays.

Returns: nothing
*/
setProp dvRowChildren[pRow] pNodesA
  _setNodeProperty sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], "children", pNodesA
  if sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["expanded"] then
    put true into sRebuildLookupTable
  end if
end dvRowChildren


/**
Summary: Returns a numerically indexed array of node arrays.

Parameters:
pRow: The target row.

Returns: Array
*/
getProp dvRowChildren[pRow]
  return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["children"]
end dvRowChildren


/**
Summary: Sets the child nodes of a node.

Parameters:
pNodeId: The target node id.
pNodesA: A numerically indexed array of child node arrays.

Description:
Setting this property will not refresh the DataView.
*/
setProp dvNodeChildren[pNodeId] pNodesA
  put _findNodeOfId(pNodeId, true) into pNodeId

  if sTreeA[ pNodeId ]["is leaf"] then throw "cannot set children property on a leaf node"

  _setNodeProperty pNodeId, "children", pNodesA

  if sTreeA[ pNodeId ]["expanded"] then
    put true into sRebuildLookupTable
  end if
end dvNodeChildren


/**
Summary: Returns a numerically indexed array of node arrays.

Parameters:
pRow: The target node id.

Returns: Array
*/
getProp dvNodeChildren[pNodeId]
  return _getNodeProperty(pNodeId, "children")
end dvNodeChildren


/**
Summary: Returns the child node at the specified position.

Parameters:
pNodeId: The parent node id. Leave empty to target the root of the tree.
pPosition: The position of the child node.

Returns: Array or empty if no child exists at that position.
*/
function GetChildNodeAtPosition pNodeId, pPosition
  if pNodeId is empty then
    put "root" into pNodeId[1]
  else
    put _findNodeOfId(pNodeId, true) into pNodeId
  end if

  if pPosition is -1 then
    return sTreeA[pNodeId]["children"][the number of elements of sTreeA[pNodeId]["children"]]
  else
    return sTreeA[pNodeId]["children"][pPosition]
  end if
end GetChildNodeAtPosition


/**
Summary: Returns an array of all children of the parent of pNodeId.

Parameters:
pNodeId: The target node id.

Returns: Array
*/
getProp dvNodeSiblings[pNodeId]
  local tParentIndexA

  put _findNodeOfId(pNodeId, true) into pNodeId
  put _parentNodeIndex(pNodeId) into tParentIndexA

  if tParentIndexA is an array then
    return sTreeA[tParentIndexA]["children"]
  else
    return empty
  end if
end dvNodeSiblings


/**
Summary: Sets the dirty flag of the row control associated with the node.

Parameters:
pNodeId: The target node id.
pIsDirty: Boolean.

Description:
This handler calls the dvRowIsDirty method of the DataView if a control is
associated with the node.
*/
setProp dvNodeIsDirty[pNodeId] pIsDirty
  _setNodeRowIsDirty pNodeId, pIsDirty
end dvNodeIsDirty


/**
Summary: Returns the dvRowIsDirty property of the row control associated with a node.

Parameters:
pNode: The target node id.

Description:
If no row control is associated with the node then `false` is always returned.

Returns: Boolean
*/
getProp dvNodeIsDirty[pNodeId]
  if sNodeIdRowLookupA[pNodeId] is an integer then
    return the dvRowIsDirty[sNodeIdRowLookupA[pNodeId]] of me
  else
    return false
  end if
end dvNodeIsDirty


/**
Summary: Returns the value for a key stored in a row's node array.

Parameters:
pRow: The target row.
pKey: The key.

Description:
This function allow you to get the value of a key in the node array that doesn't
have a built-in getProp handler.

Returns: Mixed
*/
function GetValueForKeyInRow pRow, pKey
  return GetValueForKeyInNode(sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], pKey)
end GetValueForKeyInRow


/**
Summary: Sets the value of a custom key stored in a row's node array.

Parameters:
pRow: The target row.
pKey: The custom key.
pValue: The value to assign to the key.

Description:
This function allow you to set the value of a key in the node array that is
not one of the built-in properties `id`, `type`, `expanded`, `is leaf`, `children`,
`level`, and `child count`.

Returns: nothing
*/
command SetValueForKeyInRow pRow, pKey, pValue
  _setNodeProperty sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], pKey, pValue
  return empty
end SetValueForKeyInRow


/**
Summary: Returns the key value for a node array.

Parameters:
pNodeId: The node id or index array.
pKey: The key.

Description:
See `GetValueForKeyInRow`.

Returns: Mixed
*/
function GetValueForKeyInNode pNodeId, pKey
  if pNodeId is not an array then put _findNodeOfId(pNodeId, true) into pNodeId
  return sTreeA[ pNodeId ][pKey]
end GetValueForKeyInNode


/**
Summary: Sets the value of a custom key stored in a rows node array.

Parameters:
pNodeId: The node id or index array.
pKey: The custom key.
pValue: The value to assign to the key.

Description:
See `SetValueForKeyInRow`.

Returns: nothing
*/
command SetValueForKeyInNode pNodeId, pKey, pValue
  if pKey is among the items of kBuiltInProperties then throw pKey && "is not a custom key"
  _setNodeProperty pNodeId, pKey, pValue
  return empty
end SetValueForKeyInNode


private command _setNodeProperty pNodeId, pKey, pValue
  if pNodeId is not an array then put _findNodeOfId(pNodeId, true) into pNodeId

  _setNodeRowIsDirty pNodeId, sTreeA[ pNodeId ][pKey] is not pValue
  put pValue into sTreeA[ pNodeId ][pKey]
  return empty
end _setNodeProperty


private command _setNodeRowIsDirty pNodeId, pIsDirty
  if sNodeIdRowLookupA[pNodeId] is an integer then
    set the dvRowIsDirty[sNodeIdRowLookupA[pNodeId]] of me to pIsDirty
  end if
end _setNodeRowIsDirty


/**
Summary: Returns the number of children that a node has.

Returns: Integer
*/
getProp dvNodeChildCount[pNodeId]
  put _findNodeOfId(pNodeId, true) into pNodeId
  if not sTreeA[pNodeId]["is leaf"] then
    return the number of elements of sTreeA[pNodeId]["children"]
  else
    return 0
  end if
end dvNodeChildCount


/**
Summary: Returns the row numbers of a row's children.

Returns: List
*/
getProp dvRowChildRows[pRow]
  local tList, tNodeA

  repeat for each element tNodeA in sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ]["children"]
    put sNodeIdRowLookupA[tNodeA["id"]] & "," after tList
  end repeat
  delete the last char of tList
  return tList
end dvRowChildRows


/**
Summary: Returns an integer representing the position of `pRow` amongst it's siblings.

Parameters:
pRow: The target row.

Description:
If pRow is the third child of it's parent then this property would return `3`.

Returns: Integer
*/
getProp dvRowSiblingOrder[pRow]
  return _nodePosition(sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]])
end dvRowSiblingOrder


/**
Summary: Checks if a row is the first child of its parent.

Parameters:
pRow: The row to check.

Returns: Boolean
*/
getProp dvRowIsFirstChild[pRow]
  local tIndexA, tParentIndexA

  put sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] into tIndexA
  if tIndexA is an array then
    return _nodePosition(tIndexA) is 1
  end if

  return false
end dvRowIsFirstChild


/**
Summary: Checks if a row is the last child of its parent.

Parameters:
pRow: The row to check.

Returns: Boolean
*/
getProp dvRowIsLastChild[pRow]
  local tIndexA, tParentIndexA

  put sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] into tIndexA
  if tIndexA is an array then
    put _parentNodeIndex(tIndexA) into tParentIndexA
    if tParentIndexA is an array then
      return _nodePosition(tIndexA) is the number of elements of sTreeA[tParentIndexA]["children"]
    end if
  end if

  return false
end dvRowIsLastChild


/**
Summary: Returns the tree level of a node.

Parameters:
pNode: The node `id`.

Returns: Integer
*/
getProp dvNodeLevel[pNodeId]
  put _findNodeOfId(pNodeId, true) into pNodeId
  return _nodeLevel(pNodeId)
end dvNodeLevel


/**
Summary: Returns the tree level of a row.

Parameters:
pRow: The row number.

Returns: Integer
*/
getProp dvRowLevel[pRow]
  return _nodeLevel( sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] )
end dvRowLevel


/**
Summary: Returns the row number of a rows parent.

Parameters:
pRow: The target row number.

Description:
If the row does not have a parent then 0 is returned.

Returns: Integer
*/
getProp dvRowParentRow[pRow]
  local pNodeIndexA
  put _parentNodeIndex( sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] ) into pNodeIndexA
  if pNodeIndexA is an array then
    return _rowOfNode(pNodeIndexA)
  else
    return 0
  end if
end dvRowParentRow


/**
Summary: Returns a node's parent node id.

Parameters:
pNode: The node `id`.

Description:
If the node does not have a parent then empty is returned.

Returns: Integer
*/
getProp dvNodeParentNode[pNodeId]
  local tNodeIndexA
  put _findNodeOfId(pNodeId, true) into pNodeId
  put _parentNodeIndex(pNodeId) into tNodeIndexA

  if tNodeIndexA is an array then
    return sTreeA[tNodeIndexA]["id"]
  else
    return empty
  end if
end dvNodeParentNode


/**
Summary: Returns index arrays pointing to ancestors of a row.

Parameters:
pRow: The row to get ancestor nodes for.

Returns: Numerically indexed array of index arrays
*/
getProp dvRowAncestorNodes[pRow]
  return _ancestorElements( sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]] )
end dvRowAncestorNodes


/**
Summary: Returns index arrays pointing to ancestors of a node.

Parameters:
pNode: The node `id`.

Returns: Numerically indexed array of index arrays
*/
getProp dvNodeAncestorNodes[pNodeId]
  put _findNodeOfId(pNodeId, true) into pNodeId
  return _ancestorElements(pNodeId)
end dvNodeAncestorNodes


/**
Summary: Returns the node keys of the descendants of a row.

Parameters:
pRow: The row to get descendant nodes for.

Returns: Numerically indexed array of index arrays
*/
getProp dvRowDescendantNodes[pRow]
  return _descendantElements(sNodeIdNodeLookupA[sRowNodeIdLookupA[pRow]], false)
end dvRowDescendantNodes


/**
Summary: Returns index arrays that point to the descendants of a node.

Parameters:
pNodeId: The node `id`.

Returns: Numerically indexed array of index arrays
*/
getProp dvNodeDescendantNodes[pNodeId]
  put _findNodeOfId(pNodeId, true) into pNodeId
  return _descendantElements(pNodeId, false)
end dvNodeDescendantNodes


/**
Summary: Returns the `id` property of the selected row(s).

Description:
If not rows are selected then empty is returned.

Returns: Comma-delimited list of integers
*/
getProp dvHilitedIds
  local tRow, tRows, tIds

  put the dvHilitedRow of me into tRows

  repeat for each item tRow in tRows
    if sRowNodeIdLookupA[tRow] is not empty then
      put sRowNodeIdLookupA[tRow] & "," after tIds
    end if
  end repeat
  delete the last char of tIds
  return tIds
end dvHilitedIds


getProp dvHilitedId
  return the dvHilitedIds of me
end dvHilitedId


/**
Summary: Sets the selected row based on the `id` property of a row(s).

Parameters:
pForceScroll: Passed along to `dvHilitedRow` in the DataView behavior.
pIds: Comma-delimited list of ids to hilite.

Description:
If any ids in `pIds` is not currently associated with a row then the tree
will be expanded to show it.

Note that if your ids have a "," in them then this property won't work correctly.

Returns: Comma-delimited list of ids that had their expanded state changed.
*/
setProp dvHilitedIds[pForceScroll] pIds
  local tId, tNodeIndexA, tRows
  local tModifiedNodesA, tModifiedNodeIdsA, tModifiedNodeIds

  repeat for each item tId in pIds
    if sNodeIdRowLookupA[tId] is empty then
      put _findNodeOfId(tId, false) into tNodeIndexA
      if tNodeIndexA is an array then
        _showNode tNodeIndexA
        put it into tModifiedNodesA

        # Store list of ids that had expanded state changed
        repeat for each element tNodeIndexA in tModifiedNodesA
          put empty into tModifiedNodeIdsA[sTreeA[tNodeIndexA]["id"]]
        end repeat
      end if
    end if
  end repeat

  if sRebuildLookupTable then
    _refreshView
  end if

  repeat for each item tId in pIds
    if sNodeIdRowLookupA[tId] is not empty then
      put sNodeIdRowLookupA[tId] & "," after tRows
    end if
  end repeat
  delete the last char of tRows

  put the keys of tModifiedNodeIdsA into tModifiedNodeIds
  replace cr with "," in tModifiedNodeIds

  set the dvHilitedRow[pForceScroll] of me to tRows

  return tModifiedNodeIds
end dvHilitedIds


setProp dvHilitedId[pForceScroll] pIds
  set the dvHilitedIds[pForceScroll] of me to pIds
end dvHilitedId


/**
Summary: Returns all ids that are implicitly included in the currently hilited rows.

Description:
When a parent node is selected an action such as "delete" or "move" would also
move the descendants of the parent. This property returns all ids implied
by the current selection.

Returns: Comma-delimited list
*/
getProp dvEffectiveHilitedIds
  return _effectiveHilitedIds()
end dvEffectiveHilitedIds


/**
Summary: Returns the list of all ids inherent in the current selection.

Description:
The list that is returned includes the descendants of selected rows.

Returns: Comma-delimited list
*/
private function _effectiveHilitedIds
  local tRow, tNodeIds, tNodeId, tNodeA, tNodeDescendantsA

  repeat for each item tRow in the dvHilitedRows of me
    put sRowNodeIdLookupA[tRow] into tNodeId
    put sNodeIdNodeLookupA[tNodeId] into tNodeA
    put _descendantElements(tNodeA) into tNodeDescendantsA

    if tNodeId is not among the items of tNodeIds then
      put tNodeId & "," after tNodeIds
    end if

    if tNodeDescendantsA is an array then
      repeat for each element tNodeA in tNodeDescendantsA
        if sTreeA[tNodeA]["id"] is not among the items of tNodeIds then
          put sTreeA[tNodeA]["id"] & "," after tNodeIds
        end if
      end repeat
    end if
  end repeat
  delete the last char of tNodeIds

  return tNodeIds
end _effectiveHilitedIds


/**
Summary: Returns all data for each selected row.

Description:
If not rows are selected then empty is returned.

Returns: Array or numerically indexed array of node arrays.
*/
getProp dvHilitedData
  local tRow, tRows, tIds

  put the dvHilitedRow of me into tRows

  if the number of items of tRows is 1 then
    return sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[tRows]] ]
  else
    local tDataA, i
    repeat for each item tRow in tRows
      add 1 to i
      put sTreeA[ sNodeIdNodeLookupA[sRowNodeIdLookupA[tRow]] ] into tDataA[i]
    end repeat
    return tDataA
  end if
end dvHilitedData


/**
Summary: Returns the style of tree line to draw at each level for a particular node.

Returns: Comma-delimited list. Items can be empty, `child`, `last child`, `relative`, `parent`, or `collapsed parent`.
*/
getProp dvNodeTreeLineStyles[pNodeId]
  put _findNodeOfId(pNodeId, true) into pNodeId
  if "tree line styles" is among the keys of sTreeA[ pNodeId ] then
    return sTreeA[ pNodeId ]["tree line styles"]
  else
    return _nodeTreeLineStyles(pNodeId, _nodeLevel(pNodeId))
  end if
end dvNodeTreeLineStyles



/**
Summary: Returns the style of tree line to draw at each level for a particular row.

Returns: Comma-delimited list. Items can be empty, `child`, `last child`, `relative`, `parent`, or `collapsed parent`.
*/
getProp dvRowTreeLineStyles[pRow]
  return the dvNodeTreeLineStyles[sRowNodeIdLookupA[pRow]] of me
end dvRowTreeLineStyles


/**
Summary: Renders the tree lines in an image object.

Parameters:
pRow: The row that the image object is associated with.
pRGBA: Optional Red, Green, Blue, Alpha values. If empty then the backgroundColor of the image will be used.

Description:
`dispatch` this message to an image object in a row control to draw the tree lines

Returns: nothing
*/
command RenderTreeLines pRow, pRGBA
  local tNodeId, tInset, tSpacing, tStyles
  local tLeft

  if the number of items of pRGBA is 3 then put ",255" after pRGBA

  if pRow is empty then
    put the dvRow of the dvRowControl of the target into pRow
  end if

  put sRowNodeIdLookupA[pRow] into tNodeId

  put the viewProp["line inset"] of me into tInset
  put the viewProp["line spacing"] of me into tSpacing
  put sTreeA[ sNodeIdNodeLookupA[tNodeId] ]["tree line styles"] into tStyles
  put the left of the target into tLeft

  set the text of the target to _renderTreeLines(tInset, \
        tSpacing, \
        tStyles, \
        the height of the target, \
        pRGBA)

  set the left of the target to tLeft

  return empty
end RenderTreeLines


/**
Summary: Helper function for rendering a drawing representing tree line styles.

Parameters:
pLineInset: Point representing distance from left (item 1) and top (item 2) of image to start calculations. If top is empty then half of pHeight is used.
pLineSpacing: Distance between each level of lines.
pLineStyles: Comma-delimited list of line styles for each level. Items can be empty, `child`, `last child`, `relative`, `parent`, or `collapsed parent`.
pWidth: Width of image object.
pHeight: Height of image object.
pRGBA: Red, Green, Blue, and Alpha values from 0-255. If empty alpha defaults to 255.

Description:
Level 1 starts at pLineInset.

Returns: Drawing which can be assigned to the `text` of an image
*/
function RenderTreeLinesWithOptions pLineInset, pLineSpacing, pLineStyles, pHeight, pRGBA
  if the number of items of pRGBA is 3 then put ",255" after pRGBA
  return _renderTreeLines(pLineInset, pLineSpacing, pLineStyles, pHeight, pRGBA)
end RenderTreeLinesWithOptions


/**
Summary: Render tree lines for a row in the DataView.

Parameters:
pLineInset: Point representing distance from left (item 1) and top (item 2) of image to start calculations. If top is empty then half of pHeight is used.
pLineSpacing: Distance between each level of lines.
pLineStyles: Comma-delimited list of line styles for each level. Items can be empty, `child`, `last child`, `relative`, `parent`, or `collapsed parent`.
pHeight: Height of image object.
pRGBA: Red, Green, Blue, and Alpha values from 0-255. If empty alpha defaults to 255.

Description:
Level 1 starts at pLineInset.

Returns: Drawing that can be assigned to `text` of an image.
*/
private function _renderTreeLines pLineInset, pLineSpacing, pLineStyles, pHeight, pRGBA
  local tContext, tStartX, tStartY, tX, tY
  local tStyle, tLevel, tDrawing
  local tXInset, tYInset, tWidth

  put item 1 of pLineInset into tXInset
  put item 2 of pLineInset into tYInset
  if tYInset is empty then put pHeight/2 into tYInset

  put tXInset + pLineSpacing * the number of items of pLineStyles into tWidth

  drawingStart tContext, tWidth, pHeight
  drawingSetIdentityTransform tContext
  drawingSetStrokeWidth tContext, 1
  drawingSetNoFillPaint tContext
  if pRGBA is empty then
    drawingSetCurrentColorStrokePaint tContext
  else
    drawingSetSolidColorStrokePaint tContext, \
          item 1 of pRGBA/255, \
          item 2 of pRGBA/255, \
          item 3 of pRGBA/255, \
          item 4 of pRGBA/255
  end if

  drawingTraceBeginPath tContext

  put tXInset + pLineSpacing/2 into tX
  drawingTraceMoveTo tContext, tX, 0

  repeat for each item tStyle in pLineStyles
    add 1 to tLevel

    switch tStyle
      case "relative"
        drawingTraceLineTo tContext, tX, pHeight
        break

      case "last child"
        drawingTraceLineTo tContext, tX, tYInset
        drawingTraceLineTo tContext, tX+pLineSpacing, tYInset
        break

      case "child"
        drawingTraceLineTo tContext, tX, pHeight
        drawingTraceMoveTo tContext, tX, tYInset
        drawingTraceLineTo tContext, tX+pLineSpacing, tYInset
        break

      case "parent"
        drawingTraceMoveTo tContext, tX, tYInset
        drawingTraceLineTo tContext, tX-pLineSpacing, tYInset

        drawingTraceMoveTo tContext, tX, tYInset
        drawingTraceLineTo tContext, tX, pHeight
        break

      case "collapsed parent"
        drawingTraceMoveTo tContext, tX, tYInset
        drawingTraceLineTo tContext, tX-pLineSpacing, tYInset
        break
    end switch

    put tXInset + pLineSpacing/2 + (pLineSpacing * tLevel) into tX
    drawingTraceMoveTo tContext, tX, 0
  end repeat

  drawingTraceEndPath tContext

  drawingFinish tContext, tDrawing
  return tDrawing
end _renderTreeLines


/**
Summary: Builds the lookup table used to match nodes to rows.

Returns: nothing
*/
private command _buildRowToNodeLookup
  local tRow, tIndexA

  put 0 into tRow
  put empty into sRowNodeIdLookupA
  put empty into sNodeIdNodeLookupA
  put empty into sNodeIdRowLookupA

  put "root" into tIndexA[1]
  put "children" into tIndexA[2]

  _addBranchToRowToNodeLookup sTreeA["root"]["children"], tIndexA, tRow, true

  return empty
end _buildRowToNodeLookup


/**
Summary: Adds a branch of sTreeA to the lookup table.

Returns: nothing
*/
private command _addBranchToRowToNodeLookup pTreeBranchA, pIndexA, @xRow, pBranchIsVisible
  local tLookupIndex, tIndex, tNodeA, tChildrenAreVisible

  put the number of elements of pIndexA + 1 into tLookupIndex

  repeat for each element tNodeA in pTreeBranchA
    if sNodeIdNodeLookupA[tNodeA["id"]] is an array then
      throw "duplicate node id in tree:" && tNodeA["id"]
    end if

    add 1 to tIndex
    put tIndex into pIndexA[tLookupIndex]
    put pIndexA into sNodeIdNodeLookupA[tNodeA["id"]]

    if pBranchIsVisible then
      add 1 to xRow
      put tNodeA["id"] into sRowNodeIdLookupA[xRow]
      put xRow into sNodeIdRowLookupA[tNodeA["id"]]
    end if

    if tNodeA["expanded"] is empty then put false into tNodeA["expanded"]

    if not tNodeA["is leaf"] and the number of elements of tNodeA["children"] > 0 then
      put "children" into pIndexA[tLookupIndex+1]
      put pBranchIsVisible and tNodeA["expanded"] into tChildrenAreVisible

      _addBranchToRowToNodeLookup tNodeA["children"], pIndexA, xRow, tChildrenAreVisible

      delete local pIndexA[tLookupIndex+1]
    end if
  end repeat

  return empty
end _addBranchToRowToNodeLookup


/**
Summary: Returns the node position amongst it's siblings.

Parameters:
pNode: The node index lookup array.

Returns: Integer
*/
private function _nodePosition pNode
  # The index is sibling position.
  return pNode[the number of elements of pNode]
end _nodePosition


private command _refreshView pTargetRow
  local i, tSelNodesA

  # store selected elements
  repeat for each item tRow in the dvHilitedRows of me
    add 1 to i
    put sNodeIdNodeLookupA[sRowNodeIdLookupA[tRow]] into tSelNodesA[i]
  end repeat

  lock screen
  RefreshViewRows

  # update selected rows
  # rows may no longer be available because they are contracted
  if tSelNodesA is an array then
    local tSelRows

    repeat with i = 1 to the number of elements of tSelNodesA
      put _rowOfNode(tSelNodesA[i]) into tRow
      if tRow > 0 then
        put tRow & "," after tSelRows
      end if
    end repeat
    delete the last char of tSelRows

    if tSelRows is empty then put pTargetRow into tSelRows
    set the dvHilitedRows of me to tSelRows
  end if

  unlock screen
end _refreshView


/**
Summary: Recursively sets the `expanded` key of all nodes in the tree.

Parameters:
pTreeBranchA: The array representing a branch in the tree.
pIndexA: The index array that points to the branch of the tree.
pBoolean: `true` or `false`.

Returns: nothing
*/
private command _setExpandedInTreeBranch pTreeBranchA, pIndexA, pBoolean
  local tIndex, i

  put the number of elements of pIndexA into tIndex
  add 1 to tIndex

  repeat with i = 1 to the number of elements of pTreeBranchA
    put i into pIndexA[tIndex]

    if sTreeA[pIndexA]["is leaf"] then next repeat

    if sTreeA[pIndexA]["expanded"] is not pBoolean then
      put pBoolean into sTreeA[pIndexA]["expanded"]
      _setNodeRowIsDirty sTreeA[pIndexA]["id"], true
    end if

    if sTreeA[pIndexA]["children"] is not empty then
      put "children" into pIndexA[tIndex+1]
      _setExpandedInTreeBranch sTreeA[pIndexA], pIndexA, pBoolean
      delete variable pIndexA[tIndex+1]
    end if
  end repeat
end _setExpandedInTreeBranch


/**
Summary: Returns the row associated with a node.

Parameters:
pNodeIndexA: Node index array.

Description:
This will return 0 if no row is found.

Returns: Integer
*/
private function _rowOfNode pNode
  if pNode is an array then
    put sTreeA[pNode]["id"] into pNode
  end if

  return max(0, sNodeIdRowLookupA[pNode])
end _rowOfNode


private function _getNodeProperty pNodeId, pProperty
  put _findNodeOfId(pNodeId, true) into pNodeId
  return sTreeA[pNodeId][pProperty]
end _getNodeProperty


/**
Summary: Returns the level of a node in the tree.

Returns: Integer
*/
private function _nodeLevel pNodeIndexA
  local tLevel, tKey

  repeat for each key tKey in pNodeIndexA
    if pNodeIndexA[tKey] is an integer then
      add 1 to tLevel
    end if
  end repeat

  return tLevel
end _nodeLevel


private function _findNodeOfId pNodeId, pWithValidation
  local tIndexA, tFoundIndexA

  put "root" into tIndexA[1]
  put "children" into tIndexA[2]

  put _searchBranchForNodeId(sTreeA["root"]["children"], tIndexA, pNodeId) into tFoundIndexA
  if tFoundIndexA is not an array then
    if pWithValidation then
      throw "node id not found:" && pNodeId
    else
      return empty
    end if
  else
    return tFoundIndexA
  end if
end _findNodeOfId


private function _searchBranchForNodeId pTreeBranchA, pIndexA, pNodeId
  local tIndex, tFoundIndexA, tNodeA, i

  if sNodeIdNodeLookupA[pNodeId] is an array then
    return sNodeIdNodeLookupA[pNodeId]
  else
    put the number of elements of pIndexA + 1 into tIndex

    repeat for each element tNodeA in pTreeBranchA
      add 1 to i
      put i into pIndexA[tIndex]

      if tNodeA["id"] is pNodeId then
        put pIndexA into sNodeIdNodeLookupA[pNodeId]
        return pIndexA
      end if

      if the number of elements of tNodeA["children"] > 0 then
        put "children" into pIndexA[tIndex+1]
        put _searchBranchForNodeId(tNodeA["children"], pIndexA, pNodeId) into tFoundIndexA
        delete local pIndexA[tIndex+1]

        if tFoundIndexA is an array then
          put tFoundIndexA into sNodeIdNodeLookupA[pNodeId]
          return tFoundIndexA
        end if
      end if
    end repeat
  end if

  return empty
end _searchBranchForNodeId


/**
Summary: Sets the expanded state for a node.

Parameters:
pNodeIndexA: The node index array.
pBoolean: The value to assign to the expanded state. Leave empty to toggle.

Returns: empty
*/
private command _setNodeExpandedState pNodeIndexA, pBoolean
  if pBoolean is empty then
    put not sTreeA[pNodeIndexA]["expanded"] into pBoolean
  else
    put pBoolean is true into pBoolean
  end if

  if sTreeA[pNodeIndexA]["expanded"] is not pBoolean then
    if sTreeA[pNodeIndexA]["is leaf"] is not true then
      put pBoolean into sTreeA[pNodeIndexA]["expanded"]
      _setNodeRowIsDirty sTreeA[pNodeIndexA]["id"], true
      put true into sRebuildLookupTable
    end if
  end if

  return empty
end _setNodeExpandedState


/**
Summary: Expands any tree nodes necessary so that the node can be seen.

Parameters:
pNodeIndexA: The node index array.

Returns: Array of node indexes that were expanded.
*/
private command _showNode pNodeIndexA
  local tModifiedNodesA

  if pNodeIndexA is not an array then throw "invalid node index array"

  put _parentNodeIndex(pNodeIndexA) into pNodeIndexA

  repeat while pNodeIndexA is an array
    if not sTreeA[pNodeIndexA]["is leaf"] and not sTreeA[pNodeIndexA]["expanded"] then
      _setNodeExpandedState pNodeIndexA, true
      put pNodeIndexA into tModifiedNodesA[the number of elements of tModifiedNodesA + 1]
    end if
    put _parentNodeIndex(pNodeIndexA) into pNodeIndexA
  end repeat

  return tModifiedNodesA for value
end _showNode


/**
Summary: Recursive helper command for expanding nodes.

Parameters:
pNodeIndexA: The node index array.
pExpandedState: True or false.
pLevelsDown: The number of levels down to expand. Leave empty to expand all children.
@rCurrentLevel: The current level that is being expanded. When this matches pLevelsDown or the last child is expanded then recursion stops.

Returns: empty
*/
private command _setNodeAncestorExpandedState pNodeIndexA, pExpandedState, pLevelsDown, @xCurrentLevel
  local tCurrentLevel

  put pExpandedState is true into pExpandedState

  add 1 to tCurrentLevel
  put xCurrentLevel into tCurrentLevel

  local tIndex
  put the number of elements of pNodeIndexA + 1 into tIndex
  put "children" into pNodeIndexA[tIndex]
  add 1 to tIndex

  repeat with i = 1 to the number of elements of sTreeA[pNodeIndexA]["children"]
    put i into pNodeIndexA[tIndex]
    if sTreeA[pNodeIndexA]["expanded"] is not pExpandedState then
      _setNodeExpandedState pNodeIndexA, pExpandedState
    end if

    if tCurrentLevel is not pLevelsDown then
      _setNodeAncestorExpandedState pNodeIndexA, pExpandedState, pLevelsDown, xCurrentLevel
      put tCurrentLevel into xCurrentLevel # reset for next child in loop.
    end if
  end repeat

  return empty
end _setNodeAncestorExpandedState


/**
Summary: Returns index arrays pointing to the descendants of a node.

Parameters:
pNodeIndexA: The node index array.
pOnlyVisible: Only get the visible ancestor ids.

Returns: Numerically indexed array of index arrays
*/
private function _descendantElements pNodeIndexA, pOnlyVisible
  local tDescendantsA, tIndex, tChildIndexA
  local tDescIndex

  put pOnlyVisible is true into pOnlyVisible

  if not pOnlyVisible OR \
        (pOnlyVisible AND sTreeA[pNodeIndexA]["expanded"]) then

    local tTempDescendantsA

    put pNodeIndexA into tChildIndexA
    put the number of elements of tChildIndexA + 1 into tIndex
    put "children" into tChildIndexA[tIndex]
    add 1 to tIndex

    repeat with i = 1 to the number of elements of sTreeA[pNodeIndexA]["children"]
      put i into tChildIndexA[tIndex]
      add 1 to tDescIndex
      put tChildIndexA into tDescendantsA[tDescIndex]

      put _descendantElements(tChildIndexA, pOnlyVisible) into tTempDescendantsA

      repeat with j = 1 to the number of elements of tTempDescendantsA
        add 1 to tDescIndex
        put tTempDescendantsA[j] into tDescendantsA[tDescIndex]
      end repeat
    end repeat
  end if

  return tDescendantsA
end _descendantElements


/**
Summary: Returns the index array for the parent of an index array that points to a node.
*/
private function _parentNodeIndex pNodeIndexA
  local tCount

  put the number of elements of pNodeIndexA into tCount
  if pNodeIndexA[tCount - 1] is "children" then
    delete variable pNodeIndexA[tCount]
    delete variable pNodeIndexA[tCount-1]
    return pNodeIndexA
  else
    return empty
  end if
end _parentNodeIndex


/**
Summary: Returns index arrays pointing to ancestors of a node.

Parameters:
pNodeIndexA: The node index array.

Description:
Key `1` is the index array to the parent. The last key is the index array
of the most distant ancestor.

Returns: Numerically indexed array of index arrays
*/
private function _ancestorElements pNodeIndexA
  local tAncestorsA, tIndexCount, i

  put the number of elements of pNodeIndexA into tIndexCount

  repeat forever
    if pNodeIndexA[tIndexCount-1] is "children" and pNodeIndexA[tIndexCount-2] is not "root" then
      delete variable pNodeIndexA[tIndexCount]
      delete variable pNodeIndexA[tIndexCount-1]
      subtract 2 from tIndexCount

      add 1 to i
      put pNodeIndexA into tAncestorsA[i]
    else
      exit repeat
    end if
  end repeat

  return tAncestorsA
end _ancestorElements


/**
Summary: Returns a list of styles for each level leading up to and including the node.

Parameters:
pNodeIndexA: The target node index lookup array.
pNodeLevel: The level of the node. DataForRow will already calculate this so it saves a lookup.

Description:
When drawing a tree line showing hierarchal relationships each row will draw a line
for each level represented in the row. For example, if pNodeIndexA points to a node
at level 4 then the list returned will have 4 items. Drawing code can then render these
styles in the chosen manner.

Returns: comma-delimited list. Items can be empty, `child`, last child`, `relative`, `parent` or `collapsed parent`.
*/
private function _nodeTreeLineStyles pNodeIndexA, pNodeLevel
  local tAncestorsA, i, tLevel, tLineStyles, tHasChildren
  local tIndexA, tParentIndexA

  put _ancestorElements(pNodeIndexA) into tAncestorsA

  put the number of elements of sTreeA[pNodeIndexA]["children"] > 0 into tHasChildren
  if tHasChildren then
    if sTreeA[pNodeIndexA]["expanded"] then
      put "parent" into tLineStyles
    else
      put "collapsed parent" into tLineStyles
    end if
  end if

  # The setting for each level is dependent on that child node state. So pNodeIndexA's state
  # determines the settings for pNodeLevel-1
  put pNodeLevel-1 into tLevel
  if tLevel > 0 then
    put _getLineStyleInfoForNode(pNodeIndexA, tLevel, pNodeLevel) & "," before tLineStyles

    # Ancestor array starts with parent
    repeat for each element tIndexA in tAncestorsA
      subtract 1 from tLevel
      if tLevel > 0 then
        put _getLineStyleInfoForNode(tIndexA, tLevel, pNodeLevel) & "," before tLineStyles
      end if
    end repeat
  end if

  return tLineStyles
end _nodeTreeLineStyles


/**
Summary: Returns the tree line style for a given node.

Parameters:
pIndexA: The node index lookup array.
pLevel: The level of the node.
pAnchorLevel: The level of anchor node.

Returns: empty, `relative`, `child`, or `last child`
*/
private function _getLineStyleInfoForNode pIndexA, pLevel, pAnchorLevel
  local tSiblingInfo, tSiblingOrder, tChildCount
  local tLineStyle

  /*
  Questions to ask at each level
  1. Is node the parent of the anchor level?
    Y. Is it 'last child' or 'relative'?
    N. Does node have a child that appears AFTER anchor node?
      Y. 'child'
      N. empty
  */
  if pLevel is pAnchorLevel - 1 then
    put _siblingInfo(pIndexA) into tSiblingInfo
    put item 1 of tSiblingInfo into tSiblingOrder
    put item 2 of tSiblingInfo into tChildCount

    if tSiblingOrder is tChildCount then
      put "last child" into tLineStyle
    else
      put "child" into tLineStyle
    end if
  else
    put _siblingInfo(pIndexA) into tSiblingInfo
    put item 1 of tSiblingInfo into tSiblingOrder
    put item 2 of tSiblingInfo into tChildCount

    if tSiblingOrder is tChildCount then
      put empty into tLineStyle
    else
      put "relative" into tLineStyle
    end if
  end if

  return tLineStyle
end _getLineStyleInfoForNode


/**
Summary: Returns the sibling order and total number of siblings.

Parameters:
pNodeIndexA: The index lookup array for the node.

Description:
The first item in the list is the sibling order. The second item is
the total number of siblings.

Returns: Comma-delimited list
*/
private function _siblingInfo pNodeIndexA
  local tSiblingOrder, tParentIndexA, tChildCount

  put pNodeIndexA[the number of elements of pNodeIndexA] into tSiblingOrder

  # total number of siblings
  if the number of elements of pNodeIndexA > 1 then
    put pNodeIndexA into tParentIndexA
    delete local tParentIndexA[the number of elements of tParentIndexA]
    delete local tParentIndexA[the number of elements of tParentIndexA]
    put the number of elements of sTreeA[tParentIndexA]["children"] into tChildCount
  else
    put the number of elements of sTreeA into tChildCount
  end if

  return tSiblingOrder,tChildCount
end _siblingInfo


constant kDataViewDragType = "dataview tree nodes"
local sDataViewDragType


/**
Summary: Starts a drag and drop operation using the nodes associated with the selected rows.

Description:
This builds on top of the drag and drop support built into the DataView. The
`fullDragData["private"]` will be set to a string used to carry out the drag operation. The first line
will be `the viewProp["drop operation identifier"]` property of the view. If that is empty then the
default value of `dataview tree nodes` is used. The second line is the list of node ids
that are being dragged. The third line is the long id of the source DataView Tree and the fourth
line is the short name of the source stack.

After the clipboard is locked the `nodeDragStart` message will be sent to the target of the `dragStart` message.
It will be passed three parameters:

- pRootNodeIds: The ids at the root of the nodes being dragged. These are nodes which can be moved witout affecting the parent/child relationships of the nodes being dragged.
- pNodeIds: The ids of the nodes that are being dragged.
- @rUserData: Set this parameter to a value which will be included with the internal data in the `fullDragData["private"]` property. Cannot have more than 1 line.

You can use this message to set additional `dragData` keys or to
set the `@rUserData` parameter. The `@rUserData` parameter will appear in the `pDraggingInfoA["user data"]` key
in the parameter passed to `ValidateNodeDrop` and `AcceptNodeDrop`.

Returns: nothing
*/
on dragStart
  if the viewProp["allow drag reordering"] of me is false then exit dragStart
  if the mouseControl is empty or the dvRowControl of the mouseControl is empty then exit dragStart
  if word 1 of the target is "field" and not the lockText of the target then exit dragStart

  local tTargetRows, tRow, tNodeId, tNodeA
  local tNodeDescendantsA, tProposedNodeIds, tNodeIds, tRootNodeIds, tDescendantIds

  put the dvHilitedRows of me into tTargetRows
  set the dvDragImageRow of me to item 1 of tTargetRows

  if tTargetRows is empty then exit dragStart

  # First create a list of all descendant node ids. This list will be used
  # to determine which of the selected rows is a root level node relative
  # to the nodes that are being dragged. These are the nodes that can be moved
  # without altering any of the parent/child relationships in the dragged data.
  repeat for each item tRow in tTargetRows
    put sRowNodeIdLookupA[tRow] into tNodeId
    put sNodeIdNodeLookupA[tNodeId] into tNodeA
    put _descendantElements(tNodeA) into tNodeDescendantsA

    if tNodeDescendantsA is an array then
      repeat for each element tNodeA in tNodeDescendantsA
        # We don't mind duplicates in this list
        put sTreeA[tNodeA]["id"] & "," after tDescendantIds
      end repeat
    end if
  end repeat

  # Now build up the list of all node ids and root node ids.
  repeat for each item tRow in tTargetRows
    put sRowNodeIdLookupA[tRow] into tNodeId
    put sNodeIdNodeLookupA[tNodeId] into tNodeA
    put _descendantElements(tNodeA) into tNodeDescendantsA

    if tNodeId is not among the items of tDescendantIds then
      put tNodeId & "," after tRootNodeIds
    end if

    if tNodeId is not among the items of tNodeIds then
      put tNodeId & "," after tNodeIds
    end if
    if tNodeDescendantsA is an array then
      repeat for each element tNodeA in tNodeDescendantsA
        if sTreeA[tNodeA]["id"] is not among the items of tNodeIds then
          put sTreeA[tNodeA]["id"] & "," after tNodeIds
        end if
      end repeat
    end if
  end repeat
  delete the last char of tRootNodeIds
  delete the last char of tNodeIds

  lock clipboard

  put the viewProp["drop operation identifier"] of me into sDataViewDragType
  if sDataViewDragType is empty then put kDataViewDragType into sDataViewDragType

  local tUserData

  dispatch "nodeDragStart" to the target with tRootNodeIds, tNodeIds, tUserData
  set the fullDragData["private"] to sDataViewDragType & cr & \
        tRootNodeIds & cr & \
        tNodeIds & cr & \
        the long id of me & cr & \
        the short name of this stack & cr & \
        line 1 of tUserData

  unlock clipboard

  set the dvTrackDragReorder of me to true
end dragStart


/**
Summary: Looks for drags from one DataView tree to another.

Returns: nothing
*/
on dragMove
  local tSourceDataView

  if "private" is among the lines of the keys of the fulldragData then
    lock clipboard
    if line 1 of fulldragdata["private"] is sDataViewDragType then
      put line 4 of fulldragData["private"] into tSourceDataView
    end if
    unlock clipboard
  end if

  if tSourceDataView is not the long id of me then
    # Turn on tracking for content from a different DataView
    set the dvTrackDragReorder of me to true
  end if
end dragMove


command ValidateRowDrop @xDraggingInfoA, @xProposedRow, @xProposedDropOperation
  local tSourceRootNodeIds, tSourceNodeIds, tSourceDataView, tSourceStack, tUserData
  local tDropIsAfterLastRow, tParentNodeA, tParentNodeId, tDropPosition

  set the wholematches to true

  # Reset each time through
  put empty into sDropInfoA

  if "private" is among the lines of the keys of the fulldragData then
    lock clipboard
    if line 1 of fulldragdata["private"] is sDataViewDragType then
      put line 2 of fulldragData["private"] into tSourceRootNodeIds
      put line 3 of fulldragData["private"] into tSourceNodeIds
      put line 4 of fulldragData["private"] into tSourceDataView
      put line 5 of fulldragData["private"] into tSourceStack
      put line 6 of fulldragData["private"] into tUserData
    end if
    unlock clipboard
  end if

  put (xProposedRow is the number of elements of sRowNodeIdLookupA \
        and xProposedDropOperation is "on") \
        or (xProposedRow is the number of elements of sRowNodeIdLookupA + 1 \
        and xProposedDropOperation is "above") into tDropIsAfterLastRow

  if not _rowDropValidatesAgainstRules(tSourceRootNodeIds, tSourceNodeIds, xProposedRow, xProposedDropOperation, tDropIsAfterLastRow) then
    return false
  end if

  # If dropping after last row or if proposed operation is "above" and the preceding
  # row has a different level or same level and is a headng then the preceding row becomes
  # the proposed row and the operation becomes "on" as long as the preceding row isn't
  # part of the dragged ids.
  local tUpdateProposedRow = false
  local tPrevRowNodeA, tPrevRowLevel

  put tDropIsAfterLastRow into tUpdateProposedRow
  if not tUpdateProposedRow then
    if xProposedRow > 1 and xProposedDropOperation is "above" then
      put sNodeIdNodeLookupA[sRowNodeIdLookupA[xProposedRow-1]] into tPrevRowNodeA
      put _nodeLevel(tPrevRowNodeA) into tPrevRowLevel
      put the dvRowLevel[xProposedRow] of me is not tPrevRowLevel into tUpdateProposedRow

      if not tUpdateProposedRow then
        put the dvRowLevel[xProposedRow] of me is tPrevRowLevel and \
              not sTreeA[tPrevRowNodeA]["is leaf"] into tUpdateProposedRow
      end if
    end if
  end if

  if tUpdateProposedRow then
    if tDropIsAfterLastRow or \
          (sRowNodeIdLookupA[xProposedRow-1] is not among the items of tSourceNodeIds) then
      put xProposedRow - 1 into xProposedRow
      put "on" into xProposedDropOperation
    end if
  end if

  # No rules prohibit reorder so ask instance if drop is valid.
  # Now determine the drop level
  local tDropLevel, tNodeId, tNodeA
  local tProposedRowLevel, tMaxLevel, tMinLevel

  put _levelThatMouseIsAt(xDraggingInfoA["mouseH"]) into tDropLevel

  put sRowNodeIdLookupA[xProposedRow] into tNodeId
  put sNodeIdNodeLookupA[tNodeId] into tNodeA
  put _nodeLevel(tNodeA) into tProposedRowLevel

  # max level
  put tProposedRowLevel into tMaxLevel
  if xProposedDropOperation is "on" and not sTreeA[tNodeA]["is leaf"] then
    add 1 to tMaxLevel
  end if

  # min level
  if tDropIsAfterLastRow then
    put 1 into tMinLevel
  else if xProposedDropOperation is "on" then
    put _nodeLevel(sNodeIdNodeLookupA[sRowNodeIdLookupA[xProposedRow+1]]) into tMinLevel
  else
    put tProposedRowLevel into tMinLevel
  end if

  # Finalize drop level
  put max(tMinLevel, min(tDropLevel, tMaxLevel)) into tDropLevel

  # Now that we know the level of the drop determine the target parent.
  local tAncestorsA, tLevelDiff

  put _ancestorElements(tNodeA) into tAncestorsA

  if tProposedRowLevel is tDropLevel then
    # Sibling of proposed drop row
    put tAncestorsA[1] into tParentNodeA
    put _nodePosition(tNodeA) into tDropPosition
    if xProposedDropOperation is "on" then
      add 1 to tDropPosition
    end if
  else if tProposedRowLevel+1 is tDropLevel then
    # First child of proposed drop row
    put tNodeA into tParentNodeA
    put 1 into tDropPosition
  else
    # Ancestor of proposed drop row
    put tProposedRowLevel - tDropLevel into tLevelDiff
    put tAncestorsA[tLevelDiff] into tNodeA
    if tDropLevel > 1 then
      put tAncestorsA[tLevelDiff+1] into tParentNodeA
    end if
    put "on" into xProposedDropOperation
    put _nodePosition(tNodeA) + 1 into tDropPosition
  end if

  if tParentNodeA is an array then
    put sTreeA[tParentNodeA]["id"] into tParentNodeId
  end if

  put tSourceRootNodeIds into xDraggingInfoA["root ids"]
  put tSourceNodeIds into xDraggingInfoA["ids"]
  put tSourceDataView into xDraggingInfoA["source control id"]
  put tSourceStack into xDraggingInfoA["source stack"]
  put tDropLevel into xDraggingInfoA["drop level"]
  put tUserData into xDraggingInfoA["user data"]

  dispatch "ValidateNodeDrop" with xDraggingInfoA, tParentNodeId, tDropPosition
  if the result is false then return false

  put tParentNodeId into sDropInfoA["parentNodeId"]
  put tDropPosition into sDropInfoA["childNodePosition"]

  return true
end ValidateRowDrop


command AcceptRowDrop pDraggingInfoA, pRow, pDropOperation
  dispatch "AcceptNodeDrop" with pDraggingInfoA, \
        sDropInfoA["parentNodeId"], \
        sDropInfoA["childNodePosition"]
end AcceptRowDrop


/**
Summary: Calculates the level of the outline tha the mouse is at based on horizontal position.

Returns: Integer >= 1
*/
private function _levelThatMouseIsAt pMouseH
  local tXOffset, tRootH

  put max(0, item 1 of the viewProp["line inset"] of me) into tXOffset
  add tXOffset to pMouseH
  put the left of group "dvListMask" of me + tXOffset into tRootH
  return max(1, (pMouseH - tRootH) div max(1, the viewProp["line spacing"] of me))
end _levelThatMouseIsAt


/**
Summary: Checks for certain conditions which would automatically cancel a drop operation.

Returns: Boolean
*/
private function _rowDropValidatesAgainstRules pSourceRootNodeIds, pSourceNodeIds, pProposedRow, pProposedDropOperation, pDropIsAfterLastRow
  local tNodeId

  if pSourceNodeIds is empty then return false

  put sRowNodeIdLookupA[pProposedRow] into tNodeId

  set the wholematches to true

  if tNodeId is the first item of pSourceNodeIds then
    if not (pProposedDropOperation is "above") then
      return false
    end if
  else if tNodeId is the last item of pSourceNodeIds then
    if not (pProposedDropOperation is "on") then
      return false
    end if
  else if pDropIsAfterLastRow then
    # If dropping below the last node then make sure that the parent of the last row isn't part
    # of the dragoperation. The parent cannot become a descendant of itself.
    local tParentNodeA
    put _parentNodeIndex( sNodeIdNodeLookupA[sRowNodeIdLookupA[pProposedRow-1]] ) into tParentNodeA
    if tParentNodeA is an array then
      if sTreeA[tParentNodeA]["id"] is among the items of pSourceNodeIds then
        return false
      end if
    end if
  else if tNodeId is among the items of pSourceNodeIds then
    return false
  end if

  return true
end _rowDropValidatesAgainstRules
