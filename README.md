# DataView Tree Helper

The DataView Tree helper adds support for working with tree data structures to a DataView. This is done by adding a new behavior to the DataView that is a parent behavior of the standard DataView behavior. The new behavior adds an API for setting a tree structure containing nodes, accessing properties of the nodes and associated rows, toggling the expanded state of nodes.

The helper does not provide support for creating UI elements such as an expand/contract widget. It only provides an API that your UI elements can call.

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

Your code must handle the `DataForNode` message in order to feed data to the DataView Tree for display. It looks very similar to the `DataForRow` message that a normal DataView receives but has one additional parameters – `pNodeA`. `pNodeA` contains the following keys:

- id
- type
- expanded
- is leaf
- level
- child count

```
command DataForNode pNodeA, pRow, @rDataA, @rTemplateStyle
  # Use pNodeA["id"] to locate data to feed to rData...
  # Assign values to keys in rDataA 
  # Specify the row template style to use in rTemplateStyle
end DataForNode
```

You do not need to worry about defining `NumberOfRows()` or `CacheKeyForRow()`. Both of these functions are defined in the DataView Tree behavior. The behavior returns the node `id` property in the `CacheKeyForRow()` function.

## Accessing node and row properties in the tree



## Manipulating the tree

A DataView Tree has some additional commands that can be used to manipulate the tree. For example, there is a command for toggling the expanded state of a row or one for showing a particular node.

For example, to toggle the state of the tree you can dispatch `ToggleRowIsExpanded` to a DataView:

```
put 4 into tRow
dispatch "ToggleRowIsExpanded" to group "MyDataView" with tRow
```


