---
description: ferum_std::linked_list
---

Ferum's implementation of a doubly linked list. Support addition and removal from the tail/head in O(1) time.
Duplicate values are supported.

Each value is stored internally in a table with a unique key pointing to that value. The key is generated
sequentially using a u128 counter. So the maximum number of values that can be added to the list is MAX_U128
(340282366920938463463374607431768211455).


<a name="@quick-example"></a>

# Quick Example


```
use ferum_std::linked_list::{Self, List};

// Create a list with u128 values.
let list = linked_list::new<u128>();

// Add values
linked_list::add(&mut list, 100);
linked_list::add(&mut list, 50);
linked_list::add(&mut list, 20);
linked_list::add(&mut list, 200);
linked_list::add(&mut list, 100); // Duplicate

print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100

// Get length of list.
linked_list::length(&list) // == 4

// Check if list contains value.
linked_list::contains(&list, 100) // true
linked_list::contains(&list, 10-0) // false

// Remove last
linked_list::remove_last(&list);
print_list(&list) // 100 <-> 50 <-> 20 <-> 200

// Remove first
linked_list::remove_first(&list);
print_list(&list) // 50 <-> 20 <-> 200
```




<a name="ferum_std_linked_list_LinkedList"></a>

# Resource `LinkedList`

Struct representing the linked list.


<pre><code><b>struct</b> <a href="linked_list.md#ferum_std_linked_list_LinkedList">LinkedList</a>&lt;V: drop, store&gt; <b>has</b> store, key
</code></pre>



<a name="@constants"></a>

# Constants


<a name="@duplicate_key"></a>

## DUPLICATE_KEY


<a name="ferum_std_linked_list_DUPLICATE_KEY"></a>

Thrown when a duplicate key is added to the list.


<pre><code><b>const</b> <a href="linked_list.md#ferum_std_linked_list_DUPLICATE_KEY">DUPLICATE_KEY</a>: u64 = 2;
</code></pre>



<a name="@empty_list"></a>

## EMPTY_LIST


<a name="ferum_std_linked_list_EMPTY_LIST"></a>

Thrown when a trying to perform an operation that requires a list to have elements but it
doesn't.


<pre><code><b>const</b> <a href="linked_list.md#ferum_std_linked_list_EMPTY_LIST">EMPTY_LIST</a>: u64 = 3;
</code></pre>



<a name="@key_not_found"></a>

## KEY_NOT_FOUND


<a name="ferum_std_linked_list_KEY_NOT_FOUND"></a>

Thrown when the key for a given node is not found.


<pre><code><b>const</b> <a href="linked_list.md#ferum_std_linked_list_KEY_NOT_FOUND">KEY_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a name="@functions"></a>

# Functions


<a name="ferum_std_linked_list_new"></a>

## Function `new`

Initialize a new list.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_new">new</a>&lt;V: drop, store&gt;(): <a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;
</code></pre>



<a name="ferum_std_linked_list_add"></a>

## Function `add`

Add a value to the list.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_add">add</a>&lt;V: drop, store&gt;(list: &<b>mut</b> <a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;, value: V)
</code></pre>



<a name="ferum_std_linked_list_remove_first"></a>

## Function `remove_first`

Remove the first element of the list. If the list is empty, will throw an error.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_remove_first">remove_first</a>&lt;V: drop, store&gt;(list: &<b>mut</b> <a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;)
</code></pre>



<a name="ferum_std_linked_list_remove_last"></a>

## Function `remove_last`

Remove the last element of the list. If the list is empty, will throw an error.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_remove_last">remove_last</a>&lt;V: drop, store&gt;(list: &<b>mut</b> <a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;)
</code></pre>



<a name="ferum_std_linked_list_contains"></a>

## Function `contains`

Returns true is the element is in the list.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_contains">contains</a>&lt;V: drop, store&gt;(list: &<a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;, key: u128): bool
</code></pre>



<a name="ferum_std_linked_list_length"></a>

## Function `length`

Returns the length of the list.


<pre><code><b>public</b> <b>fun</b> <a href="linked_list.md#ferum_std_linked_list_length">length</a>&lt;V: drop, store&gt;(list: &<a href="linked_list.md#ferum_std_linked_list_LinkedList">linked_list::LinkedList</a>&lt;V&gt;): u128
</code></pre>
