# DataView Tree Helper

The DataView Tree helper adds support for working with tree data structures to a [DataView](https://github.com/trevordevore/levurehelper-dataview). This is done by adding a new behavior to the DataView that is a parent behavior of the standard DataView behavior. The new behavior adds an API for setting a tree structure containing nodes, accessing properties of the nodes and associated rows, toggling the expanded state of nodes.

The helper does not provide support for creating UI elements such as an expand/contract widget. It only provides an API that your UI elements can call.

Note that this helper requires the [DataView helper](https://github.com/trevordevore/levurehelper-dataview).

## Demo

The DataView Demo application includes an example of using this helper:

https://github.com/trevordevore/dataview_demo

## Usage

In order to use the DataView Tree helper you must do two things:

1. Assign the behavior of your DataView control to `stack "DataView Tree Behavior"`. If you are already using a custom behavior with your DataView then assign the behavior of your custom behavior to `stack "DataView Tree Behavior"`.
2. Create an array in the specified format and assign it to the `dvtTree` property of the DataView.
3. Create one or more templates to display types of nodes in the tree.
4. Implement the `DataForNode` message in order to feed the tree data as needed.

## The tree array

The DataView Tree uses an array that represents a tree. This array has the last amount of data needed in order for the DataView Tree to work. The actual data that is displayed in the UI will be provided by some other data source. This data is supplied to the DataView Tree by way of the `DataForNode` message.

The array assigned to the `dvtTree` property is a numerically indexed array of node arrays (arrays nested within an array). Each node array has the following keys:

1. `id`: Uniquely identifies the node in the tree. This also links the node to a record in your data source.
2. `type`: Identifies the type of the node. This property can help you choose which row template to use for a given node.
3. `expanded`: Boolean value specifying whether or not the node is expanded. Default is `false`.
4. `children`: A numerically indexed array of child nodes.
5. `is leaf`: Boolean value specifying whether or not the node can have children. If `true` then the node cannot have children.

### Sample of keys in a tree array

```
pTreeA[1]["type"]
pTreeA[1]["id"]
pTreeA[1]["expanded"]
pTreeA[1]["is leaf"]
pTreeA[1]["children"]
pTreeA[1]["children"][1]["type"]
pTreeA[1]["children"][1]["id"]
pTreeA[1]["children"][1]["expanded"]
pTreeA[1]["children"][1]["is leaf"]
pTreeA[1]["children"][1]["children"]
pTreeA[1]["children"][1]["children"][1]["type"]
pTreeA[1]["children"][1]["children"][1]["id"]
pTreeA[1]["children"][1]["children"][1]["expanded"]
pTreeA[1]["children"][1]["children"][1]["is leaf"]
pTreeA[1]["children"][1]["children"][1]["children"]
pTreeA[2]["type"]
pTreeA[2]["id"]
pTreeA[2]["expanded"]
pTreeA[2]["is leaf"]
pTreeA[2]["children"]
...
```

## Feeding data to a DataView Tree

A standard DataView sends the `DataForRow` message. Usually there is a 1-1 mapping of data from your data source to the rows displayed in the DataView. In a tree the 1-1 mapping doesn't usually exist as a node can be collapsed which hides it's children in the UI. 

Instead, a DataView Tree sends the `DataForNode` message. Your code must handle the `DataForNode` message in order to feed data to the DataView Tree for display. It looks very similar to the `DataForRow` message that a normal DataView receives but has one additional parameters – `pNodeA`. `pNodeA` contains the following keys:

- `id`
- `type`
- `expanded`
- `is leaf`
- `level`
- `child count`

```
command DataForNode pNodeA, pRow, @rDataA, @rTemplateStyle
  # Use pNodeA["id"] to locate data in your data ource to feed to rData...
  # Assign values to keys in rDataA 
  # Specify the row template style to use in rTemplateStyle
end DataForNode
```

You can use the `pNodeA["id"]` value to locate the data in your data source that should be displayed for the node.

### NumberOfRows() and CacheKeyForRow()
You do not need to worry about defining `NumberOfRows()` or `CacheKeyForRow()`. Both of these functions are defined in the DataView Tree behavior. The behavior returns the node `id` property in the `CacheKeyForRow()` function.

## Accessing node and row properties in the tree

The API includes a number of properties for accessing node or row properties. Most properites have both a row and node version. For example, to check if a row or node is a leaf you can check the `dvtRowIsLeaf[pRow]` or `dvtNodeIsLeaf[pNodeId]` property.

## Manipulating the tree

A DataView Tree has some additional commands that can be used to manipulate the tree. For example, there is a command for toggling the expanded state of a row (`ToggleRowIsExpanded`) or one for showing a particular node (`ShowNode`).

For example, to toggle the state of the tree you can dispatch `ToggleRowIsExpanded` to a DataView:

```
put 4 into tRow
dispatch "ToggleRowIsExpanded" to group "MyDataView" with tRow
```

## API

- [CollapseAllNodes](#CollapseAllNodes)
- [dvtNodeAncestorNodes[pNodeId]](#dvtNodeAncestorNodes[pNodeId])
- [dvtNodeChildCount[pNodeId]](#dvtNodeChildCount[pNodeId])
- [dvtNodeChildNodes[pNodeId]](#dvtNodeChildNodes[pNodeId])
- [dvtNodeDescendantNodes[pNodeId]](#dvtNodeDescendantNodes[pNodeId])
>
- [dvtNodeIsExpanded[pNodeId]](#dvtNodeIsExpanded[pNodeId])
- [dvtNodeIsLeaf[pNodeId]](#dvtNodeIsLeaf[pNodeId])
- [dvtNodeLevel[pNodeId]](#dvtNodeLevel[pNodeId])
- [dvtNodeOfId[pNodeId]](#dvtNodeOfId[pNodeId])
- [dvtNodeParentNode[pNodeId]](#dvtNodeParentNode[pNodeId])
>
- [dvtNodeType[pNodeId]](#dvtNodeType[pNodeId])
- [dvTree](#dvTree)
- [dvtRowAncestorNodes[pRow]](#dvtRowAncestorNodes[pRow])
- [dvtRowChildCount[pRow]](#dvtRowChildCount[pRow])
- [dvtRowChildRows[pRow]](#dvtRowChildRows[pRow])
>
- [dvtRowDescendantNodes[pRow]](#dvtRowDescendantNodes[pRow])
- [dvtRowId[pRow]](#dvtRowId[pRow])
- [dvtRowIsExpanded[pRow]](#dvtRowIsExpanded[pRow])
- [dvtRowIsLeaf[pRow]](#dvtRowIsLeaf[pRow])
- [dvtRowLevel[pRow]](#dvtRowLevel[pRow])
>
- [dvtRowNode[pRow]](#dvtRowNode[pRow])
- [dvtRowOfId[pNodeId]](#dvtRowOfId[pNodeId])
- [dvtRowParentRow[pRow]](#dvtRowParentRow[pRow])
- [dvtRowPositionAmongSiblings[pRow]](#dvtRowPositionAmongSiblings[pRow])
- [dvtRowType[pRow]](#dvtRowType[pRow])
>
- [dvtTree](#dvtTree)
- [ExpandAllNodes](#ExpandAllNodes)
- [RefreshView](#RefreshView)
- [RenderView](#RenderView)
- [ScrollNodeDescendantsIntoView](#ScrollNodeDescendantsIntoView)
>
- [ScrollRowDescendantsIntoView](#ScrollRowDescendantsIntoView)
- [SetNodeIsExpanded](#SetNodeIsExpanded)
- [SetRowIsExpanded](#SetRowIsExpanded)
- [ShowNode](#ShowNode)
- [ToggleNodeIsExpanded](#ToggleNodeIsExpanded)
>
- [ToggleRowIsExpanded](#ToggleRowIsExpanded)

<br>

## <a name="CollapseAllNodes"></a>CollapseAllNodes

**Type**: command

**Syntax**: `CollapseAllNodes `

**Summary**: Contracts all rows in the tree.

**Returns**: nothing

**Description**:

Call `RefreshView` to redraw the view.

<br>

## <a name="dvtNodeAncestorNodes[pNodeId]"></a>dvtNodeAncestorNodes[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeAncestorNodes[pNodeId] `

**Summary**: Returns index arrays pointing to ancestors of a node.

**Returns**: Numerically indexed array of index arrays

<br>

## <a name="dvtNodeChildCount[pNodeId]"></a>dvtNodeChildCount[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeChildCount[pNodeId] `

**Summary**: Returns the number of children that a node has.

**Returns**: Integer

<br>

## <a name="dvtNodeChildNodes[pNodeId]"></a>dvtNodeChildNodes[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeChildNodes[pNodeId] `

**Summary**: Returns the node index arrays for children of a node.

**Returns**: Numerically indexed array.

<br>

## <a name="dvtNodeDescendantNodes[pNodeId]"></a>dvtNodeDescendantNodes[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeDescendantNodes[pNodeId] `

**Summary**: Returns index arrays that point to the descendants of a node.

**Returns**: Numerically indexed array of index arrays

<br>

## <a name="dvtNodeIsExpanded[pNodeId]"></a>dvtNodeIsExpanded[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeIsExpanded[pNodeId] `

**Summary**: Returns the `expanded` property of the node.

**Returns**: Boolean

<br>

## <a name="dvtNodeIsLeaf[pNodeId]"></a>dvtNodeIsLeaf[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeIsLeaf[pNodeId] `

**Summary**: Returns the `is leaf` property of the node.

**Returns**: Boolean

<br>

## <a name="dvtNodeLevel[pNodeId]"></a>dvtNodeLevel[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeLevel[pNodeId] `

**Summary**: Returns the tree level of a node.

**Returns**: Integer

<br>

## <a name="dvtNodeOfId[pNodeId]"></a>dvtNodeOfId[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeOfId[pNodeId] `

**Summary**: Finds a node by `id` and returns the index array pointing to a node in the tree.

**Returns**: Index array

**Description**:

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

<br>

## <a name="dvtNodeParentNode[pNodeId]"></a>dvtNodeParentNode[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeParentNode[pNodeId] `

**Summary**: Returns a node's parent node id.

**Returns**: Integer

**Description**:

If the node does not have a parent then empty is returned.

<br>

## <a name="dvtNodeType[pNodeId]"></a>dvtNodeType[pNodeId]

**Type**: getProp

**Syntax**: `dvtNodeType[pNodeId] `

**Summary**: Returns the `type` of the node.

**Returns**: Mixed

<br>

## <a name="dvTree"></a>dvTree

**Type**: getProp

**Syntax**: `dvTree `

**Summary**: Returns the internal tree array.

**Returns**: Array

<br>

## <a name="dvtRowAncestorNodes[pRow]"></a>dvtRowAncestorNodes[pRow]

**Type**: getProp

**Syntax**: `dvtRowAncestorNodes[pRow] `

**Summary**: Returns index arrays pointing to ancestors of a row.

**Returns**: Numerically indexed array of index arrays

<br>

## <a name="dvtRowChildCount[pRow]"></a>dvtRowChildCount[pRow]

**Type**: getProp

**Syntax**: `dvtRowChildCount[pRow] `

**Summary**: Returns the number of children that a row has.

**Returns**: Integer

<br>

## <a name="dvtRowChildRows[pRow]"></a>dvtRowChildRows[pRow]

**Type**: getProp

**Syntax**: `dvtRowChildRows[pRow] `

**Summary**: Returns the row numbers of a row's children.

**Returns**: List

<br>

## <a name="dvtRowDescendantNodes[pRow]"></a>dvtRowDescendantNodes[pRow]

**Type**: getProp

**Syntax**: `dvtRowDescendantNodes[pRow] `

**Summary**: Returns the node keys of the descendants of a row.

**Returns**: Numerically indexed array of index arrays

<br>

## <a name="dvtRowId[pRow]"></a>dvtRowId[pRow]

**Type**: getProp

**Syntax**: `dvtRowId[pRow] `

**Summary**: Returns the `id` of the row's node.

**Returns**: Mixed

<br>

## <a name="dvtRowIsExpanded[pRow]"></a>dvtRowIsExpanded[pRow]

**Type**: getProp

**Syntax**: `dvtRowIsExpanded[pRow] `

**Summary**: Returns the `expanded` property of the row's node.

**Returns**: Boolean

<br>

## <a name="dvtRowIsLeaf[pRow]"></a>dvtRowIsLeaf[pRow]

**Type**: getProp

**Syntax**: `dvtRowIsLeaf[pRow] `

**Summary**: Returns the `is leaf` property of the row's node.

**Returns**: Boolean

<br>

## <a name="dvtRowLevel[pRow]"></a>dvtRowLevel[pRow]

**Type**: getProp

**Syntax**: `dvtRowLevel[pRow] `

**Summary**: Returns the tree level of a row.

**Returns**: Integer

<br>

## <a name="dvtRowNode[pRow]"></a>dvtRowNode[pRow]

**Type**: getProp

**Syntax**: `dvtRowNode[pRow] `

**Summary**: Returns the node index array of the node associated with a row.

**Returns**: Array

<br>

## <a name="dvtRowOfId[pNodeId]"></a>dvtRowOfId[pNodeId]

**Type**: getProp

**Syntax**: `dvtRowOfId[pNodeId] `

**Summary**: Returns the row assigned to a node.

**Returns**: Integer or empty if not found

**Description**:

The row may be empty if it isn't currently visible or caching is not turned on.

<br>

## <a name="dvtRowParentRow[pRow]"></a>dvtRowParentRow[pRow]

**Type**: getProp

**Syntax**: `dvtRowParentRow[pRow] `

**Summary**: Returns the row number of a rows parent.

**Returns**: Integer

**Description**:

If the row does not have a parent then 0 is returned.

<br>

## <a name="dvtRowPositionAmongSiblings[pRow]"></a>dvtRowPositionAmongSiblings[pRow]

**Type**: getProp

**Syntax**: `dvtRowPositionAmongSiblings[pRow] `

**Summary**: Returns an integer representing the position of `pRow` amongst it's siblings.

**Returns**: Integer

**Description**:

If pRow is the third child of it's parent then this property would return `3`.

<br>

## <a name="dvtRowType[pRow]"></a>dvtRowType[pRow]

**Type**: getProp

**Syntax**: `dvtRowType[pRow] `

**Summary**: Returns the `type` of the row's node.

**Returns**: Mixed

<br>

## <a name="dvtTree"></a>dvtTree

**Type**: setProp

**Syntax**: `dvtTree <pTreeA>`

**Summary**: Sets the tree used to display source tree data.

**Returns**: nothing

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pTreeA` |  An array representing tree used to draw the tree in the DataView. |

**Description**:

Displaying a data source that has a tree structure requires two trees. The
data source itself as well as the tree used by the DataView Tree behavior.
The DataView uses an array that is populated with node arrays. A node array has
the following format:

```
pNodeA[type|id|expanded|children|is leaf]
```

A node can have other nodes as `children`. A tree is made up of one or more
nodes.

```
pTreeA[1][type|id|expanded|children|is leaf]
pTreeA[n][type|id|expanded|children|is leaf]
```

Here is an example of a tree with three nodes – one node at the root, one node
as a child of the root node, and one node as the child of the child of the root node.

```
pTreeA[1]["type"]
pTreeA[1]["id"]
pTreeA[1]["expanded"]
pTreeA[1]["is leaf"]
pTreeA[1]["children"]
pTreeA[1]["children"][1]["type"]
pTreeA[1]["children"][1]["id"]
pTreeA[1]["children"][1]["expanded"]
pTreeA[1]["children"][1]["is leaf"]
pTreeA[1]["children"][1]["children"]
pTreeA[1]["children"][1]["children"][1]["type"]
pTreeA[1]["children"][1]["children"][1]["id"]
pTreeA[1]["children"][1]["children"][1]["expanded"]
pTreeA[1]["children"][1]["children"][1]["is leaf"]
pTreeA[1]["children"][1]["children"][1]["children"]
```

At a minimum you should define the `type` and `id` properties for each node.
`id` should uniquely identify the node in the entire tree. `type` is used to
distinguish nodes from each other.
`expanded` is a boolean value and defaults to `false` if no value is present.

<br>

## <a name="ExpandAllNodes"></a>ExpandAllNodes

**Type**: command

**Syntax**: `ExpandAllNodes `

**Summary**: Expands all rows in the tree.

**Returns**: nothing

**Description**:

Call `RefreshView` to redraw the view.

<br>

## <a name="RefreshView"></a>RefreshView

**Type**: command

**Syntax**: `RefreshView `

**Summary**: Refreshes the view after toggling or showing nodes.

**Returns**: nothing

**Description**:

When calling handlers that toggle the expanded state of a node(s) the UI
is not updated. This allows you to update multiple nodes and redraw all at
once. Call this handler when you are ready to redraw the view.

<br>

## <a name="RenderView"></a>RenderView

**Type**: command

**Syntax**: `RenderView `

**Summary**: Build lookup tables so that `NumberOfRows` can return correct value.

**Returns**: nothing

<br>

## <a name="ScrollNodeDescendantsIntoView"></a>ScrollNodeDescendantsIntoView

**Type**: command

**Syntax**: `ScrollNodeDescendantsIntoView <pNode>`

**Summary**: See ScrollRowDescendantsIntoView/

**Returns**: nothing

<br>

## <a name="ScrollRowDescendantsIntoView"></a>ScrollRowDescendantsIntoView

**Type**: command

**Syntax**: `ScrollRowDescendantsIntoView <pRow>`

**Summary**: Scrolls a row and it's descendants into view.

**Returns**: nothing

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pRow` |  The target row. |

**Description**:

When expanding a row it may be desirable to scroll the newly exposed children
into view. This handler will scroll the descendants into view without pushing
pRow off the top.

<br>

## <a name="SetNodeIsExpanded"></a>SetNodeIsExpanded

**Type**: command

**Syntax**: `SetNodeIsExpanded <pNode>,<pLevelsDown>,<pExpandedState>,<pRefreshView>`

**Summary**: Sets the expanded state of a node.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pNode` |  The node `id` or the node index array. |
| `pLevelsDown` |  How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down. |
| `pExpandedState` |  Pass in a true/false to force a setting. |
| `pRefreshView` |  Pass in `false` to keep the view from being refreshed. |

**Description**:

See `SetRowIsExpanded`.

<br>

## <a name="SetRowIsExpanded"></a>SetRowIsExpanded

**Type**: command

**Syntax**: `SetRowIsExpanded <pRow>,<pLevelsDown>,<pExpandedState>,<pRefreshView>`

**Summary**: Sets the expanded state of a row.

**Returns**: Nothing

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pRow` |  The row to toggle. |
| `pLevelsDown` |  How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down. |
| `pExpandedState` |  Pass in a true/false to force a setting. |
| `pRefreshView` |  Pass in false to keep the view from being refreshed. |

**Description**:

By default the DataView will be redrawn after calling this handler and the newly displayed
children nodes will be scrolled into view. If you pass in `false` for `pRefreshView`
then call `RefreshView` to redraw the view and `ScrollRowDescendantsIntoView` to scroll
the newly displayed rows into view.

<br>

## <a name="ShowNode"></a>ShowNode

**Type**: command

**Syntax**: `ShowNode <pNode>,<pRefreshView>`

**Summary**: Expands any tree nodes necessary so that the node can be seen.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pNode` |  The node `id` or the node index array. |
| `pRefreshView` |  Pass in false to keep the view from being refreshed. |

**Description**:

By default the DataView will be redrawn after calling this handler and the node will
be scrolled into view. If you pass in `false` for `pRefreshView`
then call `RefreshView` to redraw the view and `ScrollRowIntoView` to scroll
the row into view.

<br>

## <a name="ToggleNodeIsExpanded"></a>ToggleNodeIsExpanded

**Type**: command

**Syntax**: `ToggleNodeIsExpanded <pNode>,<pLevelsDown>,<pRefreshView>`

**Summary**: Toggles the expanded state of a node.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pNode` |  The node `id` or the node index array. |
| `pLevelsDown` |  How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down. |
| `pRefreshView` |  Pass in false to keep the view from being refreshed. |

**Description**:

See `SetRowIsExpanded`.

<br>

## <a name="ToggleRowIsExpanded"></a>ToggleRowIsExpanded

**Type**: command

**Syntax**: `ToggleRowIsExpanded <pRow>,<pLevelsDown>,<pRefreshView>`

**Summary**: Toggles the expanded state of a row.

**Returns**: Nothing

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pRow` |  The row to toggle. |
| `pLevelsDown` |  How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down. |
| `pRefreshView` |  Pass in false to keep the view from being refreshed. |

**Description**:

See `SetRowIsExpanded`.


