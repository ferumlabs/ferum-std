/// ---
/// description: ferum_std::ref_linked_list
/// ---
///
/// Same as `ferum_std::linked_list` but moves values into the list instead of copying them.
/// This removes the requirement that the generic type needs the copy ability. But as a consequence,
/// removing a particular value and checking to see if the list contains a value takes linear time (we can no longer
/// store values in a table to lookup later).
///
/// Because the list stores items by moving values, all items must be removed for the list to be dropped.
///
/// | Operation                            | Worst Case Time Complexity |
/// |--------------------------------------|----------------------------|
/// | Insertion of value to tail           | O(1)                       |
/// | Deletion of value at index           | O(N)                       |
/// | Deletion of value at head            | O(1)                       |
/// | Deletion of value at tail            | O(1)                       |
///
/// Where N is the number of elements in the list.
///
/// Each value is stored internally in a table with a unique key pointing to that value. The key is generated
/// sequentially using a u128 counter. So the maximum number of values that can be added to the list is MAX_U128
/// (340282366920938463463374607431768211455).
///
/// # Quick Example
///
/// ```
/// use ferum_std::ref_linked_list::{Self, List};
///
/// // A value that can't be copied.
/// struct TestValue has store, drop {
///   value: u128,
/// }
///
/// // Helper to create TestValue.
/// fun test_value(value: u128): TestValue {
///   TestValue {
///     value,
///   }
/// }
///
/// // Create a list with `TestValue` values.
/// let list = ref_linked_list::new<TestValue>();
///
/// // Add values
/// ref_linked_list::add(&mut list, test_value(100));
/// ref_linked_list::add(&mut list, test_value(50));
/// ref_linked_list::add(&mut list, test_value(20));
/// ref_linked_list::add(&mut list, test_value(200));
/// ref_linked_list::add(&mut list, test_value(100)); // Duplicate
///
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100
///
/// // Iterate through the list, left to right, not removing elements
/// // from the list.
/// let iterator = iterator(&list);
/// while (ref_linked_list::has_next(&iterator)) {
///   let value = ref_linked_list::peek_next(&mut list, &mut iterator);
///   ref_linked_list::skip_next(&list, &mut iterator);
/// };
///
/// // Get length of list.
/// ref_linked_list::length(&list) // == 4
///
///
/// // Remove last
/// ref_linked_list::remove_last(&list);
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200
///
/// // Remove first
/// ref_linked_list::remove_first(&list);
/// print_list(&list) // 50 <-> 20 <-> 200
///
/// // Iterate through items in the list, removing values.
/// let iterator = iterator(&list);
/// while (ref_linked_list::has_next(&iterator)) {
///   ref_linked_list::get_next(&mut list, &mut iterator);
/// };
/// ```
module ferum_std::ref_linked_list {
    use aptos_std::table_with_length as table;
    use std::vector;
    #[test_only]
    use std::string;
    #[test_only]
    use ferum_std::test_utils::to_string_u128;
    #[test_only]
    use std::string::String;

    /// Thrown when the key for a given node is not found.
    const KEY_NOT_FOUND: u64 = 1;
    /// Thrown when a duplicate key is added to the list.
    const DUPLICATE_KEY: u64 = 2;
    /// Thrown when a trying to perform an operation that requires a list to have elements but it doesn't.
    const EMPTY_LIST: u64 = 3;
    /// Thrown when a trying to drop list but it is not empty.
    const NON_EMPTY_LIST: u64 = 4;
    /// Thrown when a trying to perform an operation outside the bounds of the list.
    const INDEX_BOUND_ERROR: u64 = 4;
    /// Thrown when a value being searched for is not found.
    const VALUE_NOT_FOUND: u64 = 4;
    /// Thrown when attempting to iterate beyond the limit of the linked list.
    const MUST_HAVE_NEXT_VALUE: u64 = 5;

    struct Node<V: store> has store {
        key: u128,
        value: V,
        nextKey: u128,
        nextKeyIsSet: bool,
        prevKey: u128,
        prevKeyIsSet: bool,
    }

    /// Struct representing the linked list.
    struct LinkedList<V: store> has key, store {
        nodes: table::TableWithLength<u128, Node<V>>,
        keyCounter: u128,
        length: u128,
        head: u128,
        tail: u128,
    }

    /// Used to represent a position within a doubly linked list during iteration.
    struct ListPosition<phantom V: store> has store, copy, drop {
        currentKey: u128,
        hasNextKey: bool,
        // The first time next(..) is called, the first value is returned; in other words, position is a leading pointer.
        // Without having completed flag, it would be hard to handle the last element. For example, in a list with a
        // single element, hasNextKey would be set to false, so it would be impossible to know if iteration has come to
        // a stop.
        completed: bool,
    }

    /// Initialize a new list.
    public fun new<V: store>(): LinkedList<V> {
        return LinkedList<V>{
            nodes: table::new<u128, Node<V>>(),
            keyCounter: 0,
            length: 0,
            head: 0,
            tail: 0,
        }
    }

    /// Creates a linked list with a single element.
    public fun singleton<V: store>(val: V): LinkedList<V> {
        let list = new();
        add(&mut list, val);
        list
    }

    /// Add a value to the list.
    public fun add<V: store>(list: &mut LinkedList<V>, value: V) {
        let end = list.length;
        insert_at(list, value, end);
    }

    /// Inserts a value to the given index.
    public fun insert_at<V: store>(list: &mut LinkedList<V>, value: V, idx: u128) {
        let key = list.keyCounter;
        list.keyCounter = list.keyCounter + 1;

        let node = Node{
            key,
            value,
            nextKey: 0,
            nextKeyIsSet: false,
            prevKey: 0,
            prevKeyIsSet: false,
        };

        if (list.length == 0) {
            list.head = key;
            list.tail = key;

            table::add(&mut list.nodes, key, node);
            list.length = list.length + 1;
            return
        };

        if (idx == list.length) {
            // We're inserting at the end of a non empty list.
            node.prevKeyIsSet = true;
            node.prevKey = list.tail;
            let tail = table::borrow_mut(&mut list.nodes, list.tail);
            list.tail = key;
            tail.nextKey = key;
            tail.nextKeyIsSet = true;

            table::add(&mut list.nodes, key, node);
            list.length = list.length + 1;
            return
        };

        let i = 0;
        let it = iterator(list);
        while (i <= list.length) {
            if (i == idx) {
                if (i < list.length) {
                    // Inserting at the beginning or middle of list.
                    let targetKey = peek_next_node(list, &it).key;
                    let targetNode = table::borrow_mut(&mut list.nodes, targetKey);
                    let targetNodePrevKey = targetNode.prevKey;
                    let targetNodePrevKeyIsSet = targetNode.prevKeyIsSet;
                    targetNode.prevKey = key;
                    targetNode.prevKeyIsSet = true;
                    if (targetNodePrevKeyIsSet) {
                        let targetNodePrev = table::borrow_mut(&mut list.nodes, targetNodePrevKey);
                        targetNodePrev.nextKeyIsSet = true;
                        targetNodePrev.nextKey = key;
                    };

                    node.nextKey = targetKey;
                    node.nextKeyIsSet = true;
                    if (i == 0) {
                        list.head = key;
                    }
                };
                break
            };
            skip_next(list, &mut it);
            i = i + 1;
        };

        table::add(&mut list.nodes, key, node);
        list.length = list.length + 1;
    }

    /// Removes the value at the given index from the list.
    public fun remove<V: store>(list: &mut LinkedList<V>, idx: u64): V {
        assert!(list.length > 0, EMPTY_LIST);

        let it = iterator(list);
        let i = 0;
        while (has_next(&it)) {
            if (idx == i) {
                let key = peek_next_node(list, &it).key;
                return remove_key(list, key)
            };
            skip_next(list, &mut it);
            i = i + 1;
        };

        abort INDEX_BOUND_ERROR
    }

    /// Remove the first element of the list. If the list is empty, will throw an error.
    public fun remove_first<V: store>(list: &mut LinkedList<V>): V {
        assert!(list.length > 0, EMPTY_LIST);
        let headKey = list.head;
        remove_key(list, headKey)
    }

    /// Remove the last element of the list. If the list is empty, will throw an error.
    public fun remove_last<V: store>(list: &mut LinkedList<V>): V {
        assert!(!is_empty(list), EMPTY_LIST);
        let tailKey = list.tail;
        remove_key(list, tailKey)
    }

    /// Get a reference to the first element of the list.
    public fun borrow_first<V: store>(list: &LinkedList<V>): &V {
        assert!(!is_empty(list), EMPTY_LIST);
        let node = table::borrow(&list.nodes, list.head);
        &node.value
    }

    /// Get a reference to the last element of the list.
    public fun borrow_last<V: store>(list: &LinkedList<V>): &V {
        assert!(!is_empty(list), EMPTY_LIST);
        let node = table::borrow(&list.nodes, list.tail);
        &node.value
    }

    /// Returns the length of the list.
    public fun length<V: store>(list: &LinkedList<V>): u128 {
        list.length
    }

    /// Returns true if empty.
    public fun is_empty<V: store>(list: &LinkedList<V>): bool {
        return list.length == 0
    }

    /// Returns the list as a vector. The list itself is dropped.
    public fun as_vector<V: store>(list: LinkedList<V>): vector<V> {
        let out = vector::empty();
        if (length(&list) == 0) {
            drop_empty_list(list);
            return out
        };

        let it = iterator(&list);
        while (has_next(&it)) {
            vector::push_back(&mut out, get_next(&mut list, &mut it));
        };
        drop_empty_list(list);
        out
    }

    /// Drops an empty list, throwing an error if it is not empty.
    public fun drop_empty_list<V: store>(list: LinkedList<V>) {
        assert!(length(&list) == 0, NON_EMPTY_LIST);
        let LinkedList<V>{
            nodes,
            keyCounter: _,
            length: _,
            head: _,
            tail: _,
        } = list;
        table::destroy_empty(nodes);
    }

    /// Returns a left to right iterator. First time you call next(...) will return the first value.
    /// Updating the list while iterating will abort.
    public fun iterator<V: store>(list: &LinkedList<V>): ListPosition<V> {
        assert!(!is_empty(list), EMPTY_LIST);
        ListPosition<V> {
            currentKey: list.head,
            hasNextKey: list.head != list.tail,
            completed: false,
        }
    }

    /// Returns true if there is another element left in the iterator.
    public fun has_next<V: store>(position: &ListPosition<V>): bool {
        !position.completed
    }

    /// Returns the next value, removing it from the list. Updates the current iterator position to point to the next
    /// value.
    public fun get_next<V: store>(list: &mut LinkedList<V>, position: &mut ListPosition<V>): V {
        assert!(has_next(position), MUST_HAVE_NEXT_VALUE);
        let node = get_node_ref(list, position.currentKey);
        position.currentKey = node.nextKey;
        position.completed = !position.hasNextKey;
        position.hasNextKey = if (position.hasNextKey) get_node_ref(list, node.nextKey).nextKeyIsSet else false;
        remove_key(list, node.key)
    }

    /// Updates the current iterator position to point to the next value.
    public fun skip_next<V: store>(list: &LinkedList<V>, position: &mut ListPosition<V>) {
        assert!(has_next(position), MUST_HAVE_NEXT_VALUE);
        let node = get_node_ref(list, position.currentKey);
        position.currentKey = node.nextKey;
        position.completed = !position.hasNextKey;
        position.hasNextKey = if (position.hasNextKey) get_node_ref(list, node.nextKey).nextKeyIsSet else false;
    }

    /// Returns a reference to the next value in the iterator. Value isn't removed nor is the iterator position
    /// updated.
    public fun peek_next<V: store>(list: &LinkedList<V>, position: &ListPosition<V>): &V {
        &peek_next_node(list, position).value
    }

    //
    // Private Helpers
    //

    fun drop_node<V: store>(node: Node<V>): V {
        let Node<V>{
            key: _,
            value,
            nextKey: _,
            nextKeyIsSet: _,
            prevKey: _,
            prevKeyIsSet: _,
        } = node;
        value
    }

    fun peek_next_node<V: store>(list: &LinkedList<V>, position: &ListPosition<V>): &Node<V> {
        assert!(has_next(position), MUST_HAVE_NEXT_VALUE);
        get_node_ref(list, position.currentKey)
    }

    fun get_node_ref<V: store>(list: &LinkedList<V>, key: u128): &Node<V> {
        table::borrow(&list.nodes, key)
    }

    fun get_node<V: store>(list: &mut LinkedList<V>, key: u128): Node<V> {
        table::remove(&mut list.nodes, key)
    }

    fun remove_key<V: store>(list: &mut LinkedList<V>, key: u128): V {
        assert!(table::contains(&list.nodes, key), KEY_NOT_FOUND);

        let node = table::remove(&mut list.nodes, key);
        list.length = list.length - 1;

        // Update prev node.
        if (node.prevKeyIsSet) {
            let prev = table::borrow_mut(&mut list.nodes, node.prevKey);
            prev.nextKeyIsSet = node.nextKeyIsSet;
            prev.nextKey = node.nextKey;
        };

        // Update next node.
        if (node.nextKeyIsSet) {
            let next = table::borrow_mut(&mut list.nodes, node.nextKey);
            next.prevKeyIsSet = node.prevKeyIsSet;
            next.prevKey = node.prevKey;
        };

        // Update the list.
        if (list.head == key) {
            list.head = node.nextKey;
        };
        if (list.tail == key) {
            list.tail = node.prevKey;
        };

        drop_node(node)
    }

    #[test_only]
    struct TestValue has store, drop {
        value: u128,
    }

    #[test_only]
    fun test_value(value: u128): TestValue {
        TestValue{
            value
        }
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_list_iteration_with_empty_tree() {
        let list = new<TestValue>();
        iterator(&list);
        drop_empty_list(list);
    }

    #[test]
    fun test_list_iteration_with_one_value() {
        let list = new<TestValue>();
        add(&mut list, test_value(1));

        // First value.
        let iterator = iterator(&list);
        assert!(has_next(&iterator), 0);
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(1), 0);
        assert!(!has_next(&iterator), 0);

        drop_empty_list(list);
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_list_iteration_invalid_call_to_next() {
        let list = new<TestValue>();
        add(&mut list, test_value(1));
        let iterator = iterator(&list);
        get_next(&mut list, &mut iterator);
        get_next(&mut list, &mut iterator);
        drop_empty_list(list);
    }

    #[test]
    fun test_list_iteration_with_two_values() {
        let list = new<TestValue>();
        add(&mut list, test_value(1));
        add(&mut list, test_value(2));

        // First value.
        let iterator = iterator(&list);
        assert!(has_next(&iterator), 0);
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(1), 0);
        assert!(has_next(&iterator), 0);

        // Second value.
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(2), 0);
        assert!(!has_next(&iterator), 0);

        drop_empty_list(list)
    }

    #[test]
    fun test_list_iteration_many_values_peek() {
        let list = new<TestValue>();
        add(&mut list, test_value(1));
        add(&mut list, test_value(2));
        add(&mut list, test_value(2));
        add(&mut list, test_value(1));

        let iterator = iterator(&list);

        // First value.
        assert!(has_next(&iterator), 0);
        let value = peek_next(&list, &mut iterator);
        assert!(value.value == 1, 0);
        assert!(has_next(&iterator), 0);
        let value = peek_next(&list, &mut iterator);
        assert!(value.value == 1, 0);
        assert!(has_next(&iterator), 0);

        skip_next(&list, &mut iterator);

        // Second value.
        let value = peek_next(&list, &mut iterator);
        assert!(value.value == 2, 0);
        assert!(has_next(&iterator), 0);

        skip_next(&list, &mut iterator);

        // Third value.
        let value = peek_next(&list, &mut iterator);
        assert!(value.value == 2, 0);
        assert!(has_next(&iterator), 0);

        skip_next(&list, &mut iterator);

        // Fourth value.
        let value = peek_next(&list, &mut iterator);
        assert!(value.value == 1, 0);

        skip_next(&list, &mut iterator);

        // Should not have any more values!
        assert!(!has_next(&iterator), 0);

        empty_and_drop_list(list, 4)
    }

    #[test]
    fun test_list_iteration_with_many_values() {
        let list = new<TestValue>();
        add(&mut list, test_value(1));
        add(&mut list, test_value(2));
        add(&mut list, test_value(2));
        add(&mut list, test_value(1));

        let iterator = iterator(&list);

        // First value.
        assert!(has_next(&iterator), 0);
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(1), 0);
        assert!(has_next(&iterator), 0);

        // Second value.
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(2), 0);
        assert!(has_next(&iterator), 0);

        // Third value.
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(2), 0);
        assert!(has_next(&iterator), 0);

        // Fourth value.
        let value = get_next(&mut list, &mut iterator);
        assert!(value == test_value(1), 0);

        // Should not have any more values!
        assert!(!has_next(&iterator), 0);

        drop_empty_list(list)
    }

    #[test]
    fun test_linked_list_duplicate_values() {
        let list = new<TestValue>();
        add(&mut list, test_value(5));
        add(&mut list, test_value(1));
        add(&mut list, test_value(5));
        add(&mut list, test_value(4));
        add(&mut list, test_value(1));
        add(&mut list, test_value(5));
        assert_list(&list, b"5 <-> 1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4");

        empty_and_drop_list(list, 2)
    }

    #[test]
    fun test_linked_list_all_duplicate_values() {
        let list = new<TestValue>();
        add(&mut list, test_value(5));
        add(&mut list, test_value(5));
        add(&mut list, test_value(5));
        add(&mut list, test_value(5));
        add(&mut list, test_value(5));
        add(&mut list, test_value(5));
        assert_list(&mut list, b"5 <-> 5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&mut list, b"5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&mut list, b"5 <-> 5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&mut list, b"5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&mut list, b"5 <-> 5");
        remove_last(&mut list);
        assert_list(&mut list, b"5");
        remove_last(&mut list);
        assert_list(&mut list, b"");

        drop_empty_list(list)
    }

    #[test]
    fun test_linked_list_add_remove_first() {
        let list = new<TestValue>();
        add(&mut list, test_value(5));
        add(&mut list, test_value(1));
        add(&mut list, test_value(4));
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"4");
        remove_first(&mut list);
        assert_list(&list, b"");

        drop_empty_list(list)
    }

    #[test]
    fun test_linked_list_add_remove_last() {
        let list = new<TestValue>();
        add(&mut list, test_value(5));
        add(&mut list, test_value(1));
        add(&mut list, test_value(4));
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5");
        remove_last(&mut list);
        assert_list(&list, b"");

        drop_empty_list(list)
    }

    #[test]
    fun test_linked_list_add_remove_idx() {
        let list = new<TestValue>();
        add(&mut list, test_value(5));
        add(&mut list, test_value(1));
        add(&mut list, test_value(4));
        add(&mut list, test_value(1));
        remove(&mut list, 1);
        assert_list(&list, b"5 <-> 4 <-> 1");

        empty_and_drop_list(list, 3)
    }

    #[test]
    #[expected_failure]
    fun test_linked_listremove_last_on_empty() {
        let list = new<TestValue>();
        remove_last(&mut list);

        drop_empty_list(list)
    }

    #[test]
    #[expected_failure]
    fun test_linked_listremove_first_on_empty() {
        let list = new<TestValue>();
        remove_first(&mut list);

        drop_empty_list(list)
    }

    //
    // Helpers
    //

    #[test_only]
    public fun empty_and_drop_list(list: LinkedList<TestValue>, expectedLength: u128) {
        assert!(expectedLength == length(&list), 0);
        let it = iterator(&list);
        while (has_next(&it)) {
            get_next(&mut list, &mut it);
        };
        drop_empty_list(list)
    }

    #[test_only]
    fun assert_list(list: &LinkedList<TestValue>, expected: vector<u8>) {
        assert!(list_as_string(list) == string::utf8(expected), 0);
    }

    #[test_only]
    public fun print_list(list: &LinkedList<TestValue>) {
        std::debug::print(&list_as_string(list));
    }

    #[test_only]
    fun list_as_string(list: &LinkedList<TestValue>): String {
        let output = string::utf8(b"");

        if (length(list) == 0) {
            return output
        };

        let curr = get_node_ref(list, list.head);
        string::append(&mut output, to_string_u128(curr.value.value));
        while (curr.nextKeyIsSet) {
            string::append_utf8(&mut output, b" <->");
            curr = get_node_ref(list, curr.nextKey);
            string::append_utf8(&mut output, b" ");
            string::append(&mut output, to_string_u128(curr.value.value));
        };
        output
    }
}
