/// ---
/// description: ferum_std::linked_list
/// ---
///
/// Ferum's implementation of a doubly linked list. Values stored in the list should be cheap to copy. Duplicate values
/// are supported.
///
/// | Operation                            | Worst Case Time Complexity |
/// |--------------------------------------|----------------------------|
/// | Insertion of value to tail           | O(1)                       |
/// | Deletion of value                    | O(1)                       |
/// | Deletion of value at head            | O(1)                       |
/// | Deletion of value at tail            | O(1)                       |
/// | Contains value                       | O(1)                       |
///
/// Each value is stored internally in a table with a unique key pointing to that value. The key is generated
/// sequentially using a u128 counter. So the maximum number of values that can be added to the list is MAX_U128
/// (340282366920938463463374607431768211455).
///
/// # Quick Example
///
/// ```
/// use ferum_std::linked_list::{Self, List};
///
/// // Create a list with u128 values.
/// let list = linked_list::new<u128>();
///
/// // Add values
/// linked_list::add(&mut list, 100);
/// linked_list::add(&mut list, 50);
/// linked_list::add(&mut list, 20);
/// linked_list::add(&mut list, 200);
/// linked_list::add(&mut list, 100); // Duplicate
///
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100
///
/// // Get length of list.
/// linked_list::length(&list) // == 4
///
/// // Check if list contains value.
/// linked_list::contains(&list, 100) // true
/// linked_list::contains(&list, 300) // false
///
/// // Remove last
/// linked_list::remove_last(&list);
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200
///
/// // Remove first
/// linked_list::remove_first(&list);
/// print_list(&list) // 50 <-> 20 <-> 200
/// ```
module ferum_std::linked_list {
    use aptos_std::table;
    #[test_only]
    use std::string;
    #[test_only]
    use ferum_std::test_utils::to_string_u128;
    #[test_only]
    use std::string::String;
    use std::vector;

    /// Thrown when the key for a given node is not found.
    const KEY_NOT_FOUND: u64 = 1;
    /// Thrown when a duplicate key is added to the list.
    const DUPLICATE_KEY: u64 = 2;
    /// Thrown when a trying to perform an operation that requires a list to have elements but it
    /// doesn't.
    const EMPTY_LIST: u64 = 3;
    /// Thrown when a value being searched for is not found.
    const VALUE_NOT_FOUND: u64 = 4;

    struct Node<V: store + copy + drop> has store, drop {
        key: u128,
        value: V,
        next: u128,
        nextIsSet: bool,
        prev: u128,
        prevIsSet: bool,
    }

    /// Struct representing the linked list.
    struct LinkedList<V: store + copy + drop> has key, store {
        nodes: table::Table<u128, Node<V>>,
        nodeKeys: table::Table<V, vector<u128>>,
        keyCounter: u128,
        length: u128,
        head: u128,
        tail: u128,
    }

    /// Initialize a new list.
    public fun new<V: store + copy + drop>(): LinkedList<V> {
        return LinkedList<V>{
            nodes: table::new<u128, Node<V>>(),
            nodeKeys: table::new<V, vector<u128>>(),
            keyCounter: 0,
            length: 0,
            head: 0,
            tail: 0,
        }
    }

    /// Creates a linked list with a single element.
    public fun singleton<V: store + copy + drop>(val: V): LinkedList<V> {
        let list = new();
        add(&mut list, val);
        list
    }

    /// Add a value to the list.
    public fun add<V: store + copy + drop>(list: &mut LinkedList<V>, value: V) {
        let key = list.keyCounter;
        list.keyCounter = list.keyCounter + 1;

        let nodeKeys = table::borrow_mut_with_default(&mut list.nodeKeys, value, vector::empty());
        vector::push_back(nodeKeys, key);

        let node = Node{
            key,
            value,
            next: 0,
            nextIsSet: false,
            prev: 0,
            prevIsSet: false,
        };
        if (list.length > 0) {
            node.prevIsSet = true;
            node.prev = list.tail;

            let tail = table::borrow_mut(&mut list.nodes, list.tail);
            tail.next = key;
            tail.nextIsSet = true;

            list.tail = key;
        } else {
            list.head = key;
            list.tail = key;
        };

        table::add(&mut list.nodes, key, node);
        list.length = list.length + 1;
    }

    /// Removes a value from the list. If there are duplicates, a random occurence is removed.
    public fun remove<V: store + copy + drop>(list: &mut LinkedList<V>, value: V) {
        assert!(list.length > 0, EMPTY_LIST);
        assert!(table::contains(&list.nodeKeys, value), VALUE_NOT_FOUND);

        let idxVector = table::borrow(&mut list.nodeKeys, value);
        remove_key(list, *vector::borrow(idxVector, 0));
    }

    /// Remove the first element of the list. If the list is empty, will throw an error.
    public fun remove_first<V: store + copy + drop>(list: &mut LinkedList<V>) {
        assert!(list.length > 0, EMPTY_LIST);
        let headKey = list.head;
        remove_key(list, headKey);
    }

    /// Remove the last element of the list. If the list is empty, will throw an error.
    public fun remove_last<V: store + copy + drop>(list: &mut LinkedList<V>) {
        assert!(list.length > 0, EMPTY_LIST);
        let tailKey = list.tail;
        remove_key(list, tailKey);
    }

    /// Get a reference to the first element of the list.
    public fun borrow_first<V: store + copy + drop>(list: &LinkedList<V>): &V {
        assert!(list.length > 0, EMPTY_LIST);
        let node = table::borrow(&list.nodes, list.head);
        &node.value
    }

    /// Returns true is the element is in the list.
    public fun contains<V: store + copy + drop>(list: &LinkedList<V>, value: V): bool {
        table::contains(&list.nodeKeys, value)
    }

    /// Returns the length of the list.
    public fun length<V: store + copy + drop>(list: &LinkedList<V>): u128 {
        list.length
    }

    fun get_node<V: store + copy + drop>(list: &LinkedList<V>, key: u128): &Node<V> {
        table::borrow(&list.nodes, key)
    }

    fun remove_key<V: store + copy + drop>(list: &mut LinkedList<V>, key: u128) {
        assert!(table::contains(&list.nodes, key), KEY_NOT_FOUND);

        let node = table::remove(&mut list.nodes, key);
        list.length = list.length - 1;

        let idxVector = table::borrow_mut(&mut list.nodeKeys, node.value);
        let (_, idx) = vector::index_of(idxVector, &key);
        vector::swap_remove(idxVector, idx);

        // Update prev node.
        if (node.prevIsSet) {
            let prev = table::borrow_mut(&mut list.nodes, node.prev);
            prev.nextIsSet = node.nextIsSet;
            prev.next = node.next;
        };

        // Update next node.
        if (node.nextIsSet) {
            let next = table::borrow_mut(&mut list.nodes, node.next);
            next.prevIsSet = node.prevIsSet;
            next.prev = node.prev;
        };

        // Update the list.
        if (list.head == key) {
            list.head = node.next;
        };
        if (list.tail == key) {
            list.tail = node.prev;
        };
    }

    #[test(signer = @0xCAFE)]
    fun test_linked_list_duplicate_values(signer: &signer) {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 5);
        add(&mut list, 4);
        add(&mut list, 1);
        add(&mut list, 5);
        assert_list(&list, b"5 <-> 1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4");

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    fun test_linked_list_all_duplicate_values(signer: &signer) {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5");
        remove_last(&mut list);
        assert_list(&list, b"");

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    fun test_linked_list_add_remove_first(signer: &signer) {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"4");
        remove_first(&mut list);
        assert_list(&list, b"");

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    fun test_linked_list_add_remove_last(signer: &signer) {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5");
        remove_last(&mut list);
        assert_list(&list, b"");

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    fun test_linked_list_add_remove_value(signer: &signer) {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        add(&mut list, 1);
        remove(&mut list, 1);
        let listStr = *string::bytes(&list_as_string(&list));
        assert!(listStr == b"5 <-> 1 <-> 4" || listStr == b"5 <-> 4 <-> 1", 0);

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    #[expected_failure]
    fun test_linked_listremove_last_on_empty(signer: &signer) {
        let list = new<u128>();
        remove_last(&mut list);

        move_to(signer, list);
    }

    #[test(signer = @0xCAFE)]
    #[expected_failure]
    fun test_linked_listremove_first_on_empty(signer: &signer) {
        let list = new<u128>();
        remove_first(&mut list);

        move_to(signer, list);
    }

    #[test_only]
    fun assert_list(list: &LinkedList<u128>, expected: vector<u8>) {
        assert!(list_as_string(list) == string::utf8(expected), 0);
    }

    #[test_only]
    public fun print_list(list: &LinkedList<u128>) {
        std::debug::print(&list_as_string(list));
    }

    #[test_only]
    fun list_as_string(list: &LinkedList<u128>): String {
        let output = string::utf8(b"");

        if (length(list) == 0) {
            return output
        };

        let curr = get_node(list, list.head);
        string::append(&mut output, to_string_u128(curr.value));
        while (curr.nextIsSet) {
            string::append_utf8(&mut output, b" <->");
            curr = get_node(list, curr.next);
            string::append_utf8(&mut output, b" ");
            string::append(&mut output, to_string_u128(curr.value));
        };
        output
    }
}