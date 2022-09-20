---
description: ferum_std::red_black_tree
---

Ferum's implementation of a [Red Black Tree](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree).
A red black tree is a self balancing binary tree which performs rotations tree manipulations to maintain a tree
height of log(k), where k is the number of keys in the tree. Values with duplicate keys can be inserted into the
tree - each value will stored in a linked list on each tree node. When a node no longer has any values, the node
is removed (this is referred to as key deletion). The tree only supports u128 keys because (as of writing) move
has no way to define comparators for generic types.

The tree supports the following operations with the given time complexities:

| Operation                            | Worst Case Time Complexity | Amortized Time Complexity  |
|--------------------------------------|----------------------------|----------------------------|
| Deletion of value                    | O(1)                       | O(1)                       |
| Deletion of key                      | O(log(k))                  | O(1)                       |
| Insertion of value with new key      | O(log(k))                  | O(log(k))                  |
| Insertion of value with existing key | O(1)                       | O(1)                       |
| Retrieval of min/max key             | O(1)                       | O(1)                       |


<a name="@quick-example"></a>

# Quick Example


```
use ferum_std::red_black_tree::{Self, Tree};

// Create a tree with u128 values.
let tree = red_black_tree::new<u128>();

// Insert
red_black_tree::insert(&mut tree, 100, 50);
red_black_tree::insert(&mut tree, 100, 40);
red_black_tree::insert(&mut tree, 120, 10);
red_black_tree::insert(&mut tree, 90, 5);

// Get min/max
let min = red_black_tree::min_key(&tree);
assert!(min == 90, 0);
let max = red_black_tree::max_key(&tree);
assert!(max == 90, 0);

// Delete values and keys.
red_black_tree::delete_value(&mut tree, 100, 40);
red_black_tree::delete_key(&mut tree, 90);
let min = red_black_tree::min_key(&tree);
assert!(min == 100, 0);
```




<a name="@constants"></a>

# Constants


<a name="@key_not_found"></a>

## KEY_NOT_FOUND


<a name="ferum_std_red_black_tree_KEY_NOT_FOUND"></a>

Thrown when trying to perform an operation for a specific key but the key is not set.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_KEY_NOT_FOUND">KEY_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a name="@invalid_fix_double_red_operation"></a>

## INVALID_FIX_DOUBLE_RED_OPERATION


<a name="ferum_std_red_black_tree_INVALID_FIX_DOUBLE_RED_OPERATION"></a>

Thrown when trying fix a double red but the tree doesn't follow the correct structure.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_FIX_DOUBLE_RED_OPERATION">INVALID_FIX_DOUBLE_RED_OPERATION</a>: u64 = 8;
</code></pre>



<a name="@invalid_leaf_node_has_left_child"></a>

## INVALID_LEAF_NODE_HAS_LEFT_CHILD


<a name="ferum_std_red_black_tree_INVALID_LEAF_NODE_HAS_LEFT_CHILD"></a>

Thrown when trying to perform an operation on a leaf node but that node has a left child.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_LEAF_NODE_HAS_LEFT_CHILD">INVALID_LEAF_NODE_HAS_LEFT_CHILD</a>: u64 = 9;
</code></pre>



<a name="@invalid_leaf_node_has_right_child"></a>

## INVALID_LEAF_NODE_HAS_RIGHT_CHILD


<a name="ferum_std_red_black_tree_INVALID_LEAF_NODE_HAS_RIGHT_CHILD"></a>

Thrown when trying to perform an operation on a leaf node but that node has a right child.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_LEAF_NODE_HAS_RIGHT_CHILD">INVALID_LEAF_NODE_HAS_RIGHT_CHILD</a>: u64 = 10;
</code></pre>



<a name="@invalid_leaf_node_no_parent"></a>

## INVALID_LEAF_NODE_NO_PARENT


<a name="ferum_std_red_black_tree_INVALID_LEAF_NODE_NO_PARENT"></a>

Thrown when trying to perform an operation on a leaf node but that node has no parent.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_LEAF_NODE_NO_PARENT">INVALID_LEAF_NODE_NO_PARENT</a>: u64 = 11;
</code></pre>



<a name="@invalid_outgoing_swap_edge_direction"></a>

## INVALID_OUTGOING_SWAP_EDGE_DIRECTION


<a name="ferum_std_red_black_tree_INVALID_OUTGOING_SWAP_EDGE_DIRECTION"></a>

Thrown when the edges being swapped doesn't define a valid edge direction.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_OUTGOING_SWAP_EDGE_DIRECTION">INVALID_OUTGOING_SWAP_EDGE_DIRECTION</a>: u64 = 6;
</code></pre>



<a name="@invalid_rotation_nodes"></a>

## INVALID_ROTATION_NODES


<a name="ferum_std_red_black_tree_INVALID_ROTATION_NODES"></a>

Thrown when trying to perform an invalid rotation on the tree.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_INVALID_ROTATION_NODES">INVALID_ROTATION_NODES</a>: u64 = 3;
</code></pre>



<a name="@only_leaf_nodes_can_be_added"></a>

## ONLY_LEAF_NODES_CAN_BE_ADDED


<a name="ferum_std_red_black_tree_ONLY_LEAF_NODES_CAN_BE_ADDED"></a>

Thrown when trying to add a non leaf node to the tree.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_ONLY_LEAF_NODES_CAN_BE_ADDED">ONLY_LEAF_NODES_CAN_BE_ADDED</a>: u64 = 7;
</code></pre>



<a name="@successor_for_leaf_node"></a>

## SUCCESSOR_FOR_LEAF_NODE


<a name="ferum_std_red_black_tree_SUCCESSOR_FOR_LEAF_NODE"></a>

Thrown when trying to get the successor for a leaf node.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_SUCCESSOR_FOR_LEAF_NODE">SUCCESSOR_FOR_LEAF_NODE</a>: u64 = 5;
</code></pre>



<a name="@tree_is_empty"></a>

## TREE_IS_EMPTY


<a name="ferum_std_red_black_tree_TREE_IS_EMPTY"></a>

Thrown when trying to perform an operation on the tree that requires the tree to be non empty.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_TREE_IS_EMPTY">TREE_IS_EMPTY</a>: u64 = 0;
</code></pre>



<a name="@value_not_found"></a>

## VALUE_NOT_FOUND


<a name="ferum_std_red_black_tree_VALUE_NOT_FOUND"></a>

Thrown when attempting to delete a value that doesn't exist.


<pre><code><b>const</b> <a href="red_black_tree.md#ferum_std_red_black_tree_VALUE_NOT_FOUND">VALUE_NOT_FOUND</a>: u64 = 2;
</code></pre>



<a name="@functions"></a>

# Functions


<a name="ferum_std_red_black_tree_new"></a>

## Function `new`

Creates a new tree.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_new">new</a>&lt;V: drop, store&gt;(): <a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_red_black_tree_is_empty"></a>

## Function `is_empty`

Returns if the tree is empty.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_is_empty">is_empty</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;): bool
</code></pre>



<a name="ferum_std_red_black_tree_contains_key"></a>

## Function `contains_key`

Returns true if the tree has at least one value with the given key.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_contains_key">contains_key</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;, key: u128): bool
</code></pre>



<a name="ferum_std_red_black_tree_key_count"></a>

## Function `key_count`

Returns how many keys are in the tree.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_key_count">key_count</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;): u128
</code></pre>



<a name="ferum_std_red_black_tree_value_count"></a>

## Function `value_count`

Returns the total number of values in the tree.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_value_count">value_count</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;): u128
</code></pre>



<a name="ferum_std_red_black_tree_key_value_count"></a>

## Function `key_value_count`

Returns the total number of values for the given key.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_key_value_count">key_value_count</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;, key: u128): u128
</code></pre>



<a name="ferum_std_red_black_tree_first_value_at"></a>

## Function `first_value_at`

Returns the first value with the givem key.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_first_value_at">first_value_at</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;, key: u128): &V
</code></pre>



<a name="ferum_std_red_black_tree_values_at"></a>

## Function `values_at`

Returns all the values with the given key.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_values_at">values_at</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;, key: u128): &<a href="">vector</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_red_black_tree_max_key"></a>

## Function `max_key`

Returns the maximum key in the tree, if one exists.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_max_key">max_key</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;): u128
</code></pre>



<a name="ferum_std_red_black_tree_min_key"></a>

## Function `min_key`

Returns the minimum key in the tree, if one exists.


<pre><code><b>public</b> <b>fun</b> <a href="red_black_tree.md#ferum_std_red_black_tree_min_key">min_key</a>&lt;V: drop, store&gt;(tree: &<a href="red_black_tree.md#ferum_std_red_black_tree_Tree">red_black_tree::Tree</a>&lt;V&gt;): u128
</code></pre>
