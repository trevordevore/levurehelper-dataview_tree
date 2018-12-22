# DataView Tree Helper

The DataView Tree helper adds support for working with tree data structures to a DataView. This is done by adding a new behavior to the DataView that is a parent behavior of the standard DataView behavior. The new behavior adds commands for toggling the expanded state of nodes in a tree, expanding any nodes in the tree necessary to show a specific node, determining node ancestry, and descendants, finding nodes, determining the level of a node, and determining relative row position of a child to a parent.

In order to use the DataView Tree helper you must do two things:

1. Assign the behavior of your DataView control to `stack "DataView Tree Behavior"`. If you are already using a custom behavior with your DataView then assign the behavior of your custom behavior to `stack "DataView Tree Behavior"`.
2. Use an array for the data source with specific keys. The behavior script will need to modify the array in order to manipulate the tree.

## The data source array

When working with a tree you need to use an array with specific keys. At the root of the array are two keys:

1. `nodes`: the value is an array of key=>value pairs. The `value` contains the an array of data for the node. This data will be displayed in the row that the node is rendered into. The `key` uniquely identifies the node within the tree.
2. `visible nodes`: the value is a comma-delimited list of keys from the `nodes` array that are currently visible in the tree. The nodes will be displayed in the order they appear in the list.

In order to establish hierarchy each row in the `nodes` key of the data source has the following keys:

1. `children`: A comma-delimted list of the unique ids of child nodes.
2. `parent`: The unique id of the parent node.
3. `expanded`: Boolean value specifying whether or not the node is expanded. Default is `true`.
4. `is leaf`: Boolean value specifying whether or not the node can have children. If `true` then the node cannot have children.

### Sample data source array

```
local tDataA

# Create a parent with a single child
put "Parent 1" into tDataA["nodes"][1000]["title"]
put 1002 into tDataA["nodes"][1000]["children"]
put true into tDataA["nodes"][1000]["expanded"]

put "Child 1 of Parent 1" into tDataA["nodes"][1002]["title"]
put 1000 into tDataA["nodes"][1002]["parent"]
put true into tDataA["nodes"][1002]["is leaf"]

# Create another parent with a single child. The child is not expanded.
put "Parent 2" into tDataA["nodes"][1001]["title"]
put 1003 into tDataA["nodes"][1001]["children"]
put false into tDataA["nodes"][1000]["expanded"]

put "Child 1 of Parent 2" into tDataA["nodes"][1003]["title"]
put 1001 into tDataA["nodes"][1003]["parent"]
put true into tDataA["nodes"][1002]["is leaf"]

# Specify which ids are displayed in the tree. Since "Parent 2" is 
# not expanded "Child 1 of Parent 2"'s id is not included in the list.
put "1000,1001,1002" into tDataA["visible nodes"]
```

## Feeding data to a DataView

When feeding a data source array to the DataView using `DataForRow`, `NumberOfRows()`, and `cacheKeyForRow()` you will use the `visible object keys` to determine the number of rows and the data to provide for a given row.

Here is an example that assumes a script local variable named `sDataA` has already been created and that `sDataA["nodes"]` keys are unique ids.

```
command DataForRow pRow, @rDataA, @pTemplateStyle
  put item pRow of sDataA["visible object keys"] into tId
  put sDataA["nodes"][tId] into rDataA

  put "default" into pTemplateStyle
end DataForRow

function NumberOfRows
  return the number of items of sDataA["visible object keys"]
end NumberOfRows

function CacheKeyForRow pRow
  return item pRow of sDataA["visible object keys"]
end CacheKeyForRow
```

## Manipulating the tree

A DataView that is using the DataView tree behavior has some additional commands that can be used to manipulate the tree. For example, there is a command for toggle the expanded state of a row or one for showing a particular node. In order to manipulate the tree you will need to pass your data source array to the commands. This is necessary as keys within the array will be modified.

For example, to toggle the state of the tree you can send `TreeToggleRow` to a DataView:

```
put 4 into tRow
dispatch "TreeToggleRow" to group "MyDataView" with sDataSetA, tRow
```

The list stored in `sDataSetA["visible nodes"]` will be updated and the `expanded` key of the data from `sDataSetA["nodes"]` associated with row 4 will be updated.  
