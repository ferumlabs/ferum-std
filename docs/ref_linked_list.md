---
description: ferum_std::ref_linked_list
---

Same as <code>ferum_std::linked_list</code> but moves values into the list instead of copying them.
This removes the requirement that the generic type needs the copy ability. But as a consequence,
removing a particular value and checking to see if the list contains a value takes linear time (we can no longer
store values in a table to lookup later).

Because the list stores items by moving values, all items must be removed for the list to be dropped.

| Operation                            | Worst Case Time Complexity |
|--------------------------------------|----------------------------|
| Insertion of value to tail           | O(1)                       |
| Deletion of value at index           | O(N)                       |
| Deletion of value at head            | O(1)                       |
| Deletion of value at tail            | O(1)                       |

Where N is the number of elements in the list.

Each value is stored internally in a table with a unique key pointing to that value. The key is generated
sequentially using a u128 counter. So the maximum number of values that can be added to the list is MAX_U128
(340282366920938463463374607431768211455).


<a name="@quick-example"></a>

# Quick Example


```
use ferum_std::ref_linked_list::{Self, List};

// A value that can't be copied.
struct TestValue has store, drop {
value: u128,
}

// Helper to create TestValue.
fun test_value(value: u128): TestValue {
TestValue {
value,
}
}

// Create a list with <code>TestValue</code> values.
let list = ref_linked_list::new<TestValue>();

// Add values
ref_linked_list::add(&mut list, test_value(100));
ref_linked_list::add(&mut list, test_value(50));
ref_linked_list::add(&mut list, test_value(20));
ref_linked_list::add(&mut list, test_value(200));
ref_linked_list::add(&mut list, test_value(100)); // Duplicate

print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100

// Iterate through the list, left to right, not removing elements
// from the list.
let iterator = iterator(&list);
while (ref_linked_list::has_next(&iterator)) {
let value = ref_linked_list::peek_next(&mut list, &mut iterator);
ref_linked_list::skip_next(&list, &mut iterator);
};

// Get length of list.
ref_linked_list::length(&list) // == 4


// Remove last
ref_linked_list::remove_last(&list);
print_list(&list) // 100 <-> 50 <-> 20 <-> 200

// Remove first
ref_linked_list::remove_first(&list);
print_list(&list) // 50 <-> 20 <-> 200

// Iterate through items in the list, removing values.
let iterator = iterator(&list);
while (ref_linked_list::has_next(&iterator)) {
ref_linked_list::get_next(&mut list, &mut iterator);
};
```




<a name="ferum_std_ref_linked_list_LinkedList"></a>

# Resource `LinkedList`

Struct representing the linked list.


<pre><code><b>struct</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">LinkedList</a>&lt;V: store&gt; <b>has</b> store, key
</code></pre>



<a name="ferum_std_ref_linked_list_ListPosition"></a>

# Struct `ListPosition`

Used to represent a position within a doubly linked list during iteration.


<pre><code><b>struct</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ListPosition</a>&lt;V: store&gt; <b>has</b> <b>copy</b>, drop, store
</code></pre>



<a name="@constants"></a>

# Constants


<a name="@duplicate_key"></a>

## DUPLICATE_KEY


<a name="ferum_std_ref_linked_list_DUPLICATE_KEY"></a>

Thrown when a duplicate key is added to the list.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_DUPLICATE_KEY">DUPLICATE_KEY</a>: u64 = 2;
</code></pre>



<a name="@empty_list"></a>

## EMPTY_LIST


<a name="ferum_std_ref_linked_list_EMPTY_LIST"></a>

Thrown when a trying to perform an operation that requires a list to have elements but it doesn't.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_EMPTY_LIST">EMPTY_LIST</a>: u64 = 3;
</code></pre>



<a name="@key_not_found"></a>

## KEY_NOT_FOUND


<a name="ferum_std_ref_linked_list_KEY_NOT_FOUND"></a>

Thrown when the key for a given node is not found.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_KEY_NOT_FOUND">KEY_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a name="@must_have_next_value"></a>

## MUST_HAVE_NEXT_VALUE


<a name="ferum_std_ref_linked_list_MUST_HAVE_NEXT_VALUE"></a>

Thrown when attempting to iterate beyond the limit of the linked list.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_MUST_HAVE_NEXT_VALUE">MUST_HAVE_NEXT_VALUE</a>: u64 = 5;
</code></pre>



<a name="@value_not_found"></a>

## VALUE_NOT_FOUND


<a name="ferum_std_ref_linked_list_VALUE_NOT_FOUND"></a>

Thrown when a value being searched for is not found.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_VALUE_NOT_FOUND">VALUE_NOT_FOUND</a>: u64 = 4;
</code></pre>



<a name="@index_bound_error"></a>

## INDEX_BOUND_ERROR


<a name="ferum_std_ref_linked_list_INDEX_BOUND_ERROR"></a>

Thrown when a trying to perform an operation outside the bounds of the list.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_INDEX_BOUND_ERROR">INDEX_BOUND_ERROR</a>: u64 = 4;
</code></pre>



<a name="@non_empty_list"></a>

## NON_EMPTY_LIST


<a name="ferum_std_ref_linked_list_NON_EMPTY_LIST"></a>

Thrown when a trying to drop list but it is not empty.


<pre><code><b>const</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_NON_EMPTY_LIST">NON_EMPTY_LIST</a>: u64 = 4;
</code></pre>



<a name="@functions"></a>

# Functions


<a name="ferum_std_ref_linked_list_new"></a>

## Function `new`

Initialize a new list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_new">new</a>&lt;V: store&gt;(): <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_ref_linked_list_singleton"></a>

## Function `singleton`

Creates a linked list with a single element.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_singleton">singleton</a>&lt;V: store&gt;(val: V): <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_ref_linked_list_add"></a>

## Function `add`

Add a value to the list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_add">add</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, value: V)
</code></pre>



<a name="ferum_std_ref_linked_list_insert_at"></a>

## Function `insert_at`

Inserts a value to the given index.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_insert_at">insert_at</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, value: V, idx: u128)
</code></pre>



<a name="ferum_std_ref_linked_list_remove"></a>

## Function `remove`

Removes the value at the given index from the list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_remove">remove</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, idx: u64): V
</code></pre>



<a name="ferum_std_ref_linked_list_remove_first"></a>

## Function `remove_first`

Remove the first element of the list. If the list is empty, will throw an error.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_remove_first">remove_first</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): V
</code></pre>



<a name="ferum_std_ref_linked_list_remove_last"></a>

## Function `remove_last`

Remove the last element of the list. If the list is empty, will throw an error.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_remove_last">remove_last</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): V
</code></pre>



<a name="ferum_std_ref_linked_list_borrow_first"></a>

## Function `borrow_first`

Get a reference to the first element of the list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_borrow_first">borrow_first</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): &V
</code></pre>



<a name="ferum_std_ref_linked_list_borrow_last"></a>

## Function `borrow_last`

Get a reference to the last element of the list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_borrow_last">borrow_last</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): &V
</code></pre>



<a name="ferum_std_ref_linked_list_length"></a>

## Function `length`

Returns the length of the list.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_length">length</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): u128
</code></pre>



<a name="ferum_std_ref_linked_list_is_empty"></a>

## Function `is_empty`

Returns true if empty.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_is_empty">is_empty</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): bool
</code></pre>



<a name="ferum_std_ref_linked_list_as_vector"></a>

## Function `as_vector`

Returns the list as a vector. The list itself is dropped.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_as_vector">as_vector</a>&lt;V: store&gt;(list: <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): <a href="">vector</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_ref_linked_list_drop_empty_list"></a>

## Function `drop_empty_list`

Drops an empty list, throwing an error if it is not empty.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_drop_empty_list">drop_empty_list</a>&lt;V: store&gt;(list: <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;)
</code></pre>



<a name="ferum_std_ref_linked_list_iterator"></a>

## Function `iterator`

Returns a left to right iterator. First time you call next(...) will return the first value.
Updating the list while iterating will abort.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_iterator">iterator</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;): <a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ref_linked_list::ListPosition</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_ref_linked_list_has_next"></a>

## Function `has_next`

Returns true if there is another element left in the iterator.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_has_next">has_next</a>&lt;V: store&gt;(position: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ref_linked_list::ListPosition</a>&lt;V&gt;): bool
</code></pre>



<a name="ferum_std_ref_linked_list_get_next"></a>

## Function `get_next`

Returns the next value, removing it from the list. Updates the current iterator position to point to the next
value.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_get_next">get_next</a>&lt;V: store&gt;(list: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, position: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ref_linked_list::ListPosition</a>&lt;V&gt;): V
</code></pre>



<a name="ferum_std_ref_linked_list_skip_next"></a>

## Function `skip_next`

Updates the current iterator position to point to the next value.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_skip_next">skip_next</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, position: &<b>mut</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ref_linked_list::ListPosition</a>&lt;V&gt;)
</code></pre>



<a name="ferum_std_ref_linked_list_peek_next"></a>

## Function `peek_next`

Returns a reference to the next value in the iterator. Value isn't removed nor is the iterator position
updated.


<pre><code><b>public</b> <b>fun</b> <a href="ref_linked_list.md#ferum_std_ref_linked_list_peek_next">peek_next</a>&lt;V: store&gt;(list: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_LinkedList">ref_linked_list::LinkedList</a>&lt;V&gt;, position: &<a href="ref_linked_list.md#ferum_std_ref_linked_list_ListPosition">ref_linked_list::ListPosition</a>&lt;V&gt;): &V
</code></pre>
