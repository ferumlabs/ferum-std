

module ferum_std::binary_search_tree {
    use std::vector;
    use aptos_std::table;
    use ferum_std::test_utils::to_string_u128;
    use ferum_std::test_utils::to_string_vector;
    use std::string::{Self, String};

    ///
    /// ERRORS
    ///
    const TREE_IS_EMPTY: u64 = 0;
    const KEY_NOT_SET: u64 = 1;
    const NODE_NOT_FOUND: u64 = 2;


    ///
    /// STRUCTS
    ///
    struct Tree<V: store> has key {
        length: u128,
        rootNodeKey: u128,
        nodes: table::Table<u128, Node<V>>
    }

    struct Node<V: store + drop> has store, drop {
        key: u128,

        // Storing an array of values here since we want to support duplicates.
        values: vector<V>,

        // Since structs do not support self-referential cycles, we're using a table key pointing to a  node.
        // We could also use a sentinel value, but this could collide with a real key, and that's bad.
        leftChildNodeKey: u128,
        rigthChildNodeKey: u128,

        // No null or optinal values, so we need to indicate whether the children have been set.
        leftChildNodeKeyIsSet: bool,
        rigthChildNodeKeyIsSet: bool,

        // Used in the self-balancing implementation for a red-black tree; true if red, fasel if black.
        isRed: bool,
    }

    ///
    /// PUBLIC CONSTRUCTORS
    ///

    public fun new<V: store + drop>(): Tree<V> {
        Tree<V> {length: 0, rootNodeKey: 0, nodes: table::new<u128, Node<V>>()}
    }

    ///
    /// PUBLIC ACCESSORS
    ///

    public fun isEmpty<V: store + drop>(tree: &Tree<V>): bool {
        tree.length == 0
    }

    public fun length<V: store + drop>(tree: &Tree<V>): u128 {
        tree.length
    }

    public fun peek<V: store + drop>(tree: &Tree<V>): (u128, &V) {
        assert!(!isEmpty(tree), TREE_IS_EMPTY);
        let rootNode = root_node(tree);
        let rootNodeFirstValue = vector::borrow<V>(&rootNode.values, 0);
        (tree.rootNodeKey, rootNodeFirstValue)
    }

    public fun containsKey<V: store + drop>(tree: &Tree<V>, key: u128): bool {
        table::contains(&tree.nodes, key)
    }

    public fun valueAtKey<V: store + drop>(tree: &Tree<V>, key: u128): &V {
        assert!(!isEmpty(tree), TREE_IS_EMPTY);
        assert!(containsKey(tree, key), KEY_NOT_SET);
        let node = node_wity_key(tree, key);
        vector::borrow<V>(&node.values, 0)
    }

    public fun valuesAtKey<V: store + drop>(tree: &Tree<V>, key: u128): &vector<V> {
        assert!(!isEmpty(tree), TREE_IS_EMPTY);
        assert!(containsKey(tree, key), KEY_NOT_SET);
        let node = node_wity_key(tree, key);
        &node.values
    }

    ///
    /// PRIVATE ACCESSORS
    ///

    fun root_node<V: store + drop>(tree: &Tree<V>): &Node<V> {
        assert!(!isEmpty(tree), TREE_IS_EMPTY);
        node_wity_key(tree, tree.rootNodeKey)
    }

    fun node_wity_key_mut<V: store + drop>(tree: &mut Tree<V>, key: u128): &mut Node<V> {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow_mut(&mut tree.nodes, key)
    }

    fun node_wity_key<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow(&tree.nodes, key)
    }

    fun is_node_red<V: store + drop>(tree: &Tree<V>, key: u128): bool {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        node_wity_key(tree, key).isRed
    }

    ///
    /// INSERTION
    ///

    public fun insert<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V) {
        if (isEmpty(tree)) {
            // If the tree is empty, instantiate a new root!
            let rootNode = leafNode<V>(key, value);
            tree.length = tree.length + 1;
            tree.rootNodeKey = key;
            table::add(&mut tree.nodes, key, rootNode);
        } else {
            // Otherwise, recursively insert starting at the root node.
            let rootNodeKey = tree.rootNodeKey;
            insert_starting_at_node(tree, key, value, rootNodeKey);
        }
    }

    public fun insert_starting_at_node<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V, nodeKey: u128) {
        let node = node_wity_key_mut(tree, nodeKey);
        if (key == node.key) {
            vector::push_back(&mut node.values, value);
            tree.length = tree.length + 1;
        } else if (key < node.key) {
            // Key is lower than the current value, so go towards left.
            if (node.leftChildNodeKeyIsSet) {
                insert_starting_at_node(tree, key, value, node.leftChildNodeKey);
            } else {
                // Insert new left child node.
                let newNode = leafNode(key, value);
                node.leftChildNodeKey = key;
                node.leftChildNodeKeyIsSet = true;
                freeze(node);
                table::add(&mut tree.nodes, key, newNode);
                tree.length = tree.length + 1;
            }
        } else if (key > node.key) {
            // Key is lower than the current value, so go towards right.
            if (node.rigthChildNodeKeyIsSet) {
                insert_starting_at_node(tree, key, value, node.rigthChildNodeKey);
            } else {
                // Insert new right child node.
                let newNode = leafNode(key, value);
                node.rigthChildNodeKey = key;
                node.rigthChildNodeKeyIsSet = true;
                freeze(node);
                table::add(&mut tree.nodes, key, newNode);
                tree.length = tree.length + 1;
            }
        }
    }

    #[test_only]
    fun preorder<V: store + drop>(tree: &Tree<V>): vector<u128> {
        let preorderVector = &mut vector::empty<u128>();
        if (!isEmpty(tree)) {
            let treeRootNode = tree.rootNodeKey;
            preorder_starting_at_node(tree, preorderVector, treeRootNode);
        };
        return *preorderVector
    }

    #[test_only]
    fun preorder_starting_at_node<V: store + drop>(tree: &Tree<V>, results: &mut vector<u128>, currentNodeKey: u128) {
        let currentNode = node_wity_key(tree, currentNodeKey);
        vector::push_back(results, currentNodeKey);
        if (currentNode.leftChildNodeKeyIsSet) {
            preorder_starting_at_node(tree, results, currentNode.leftChildNodeKey)
        };
        if (currentNode.rigthChildNodeKeyIsSet) {
            preorder_starting_at_node(tree, results, currentNode.rigthChildNodeKey)
        }
    }

    #[test_only]
    /// Creates key_1: [v1, v2, v3], key_2: [v1, v2, v3] string for testing
    /// purposes.
    fun preorder_string_with_values(tree: &Tree<u128>): String {
        let preorderKeys = preorder(tree);
        let i = 0;
        let buffer = &mut string::utf8(b"");
        let len = vector::length(&preorderKeys);
        while (i < len) {
            // Appends "key: [v1, v2, v3]" with an optional comma separator at the end.
            let key = *vector::borrow(&preorderKeys, i);
            string::append(buffer, to_string_u128(key));
            string::append(buffer, string::utf8(if (is_node_red(tree, key)) b"(R)" else b"(B)"));
            string::append(buffer, string::utf8(b": ["));
            string::append(buffer, to_string_vector(valuesAtKey(tree, key), b", "));
            string::append(buffer, string::utf8(b"]"));
            i = i + 1;
            if (i < len) {
                string::append(buffer, string::utf8(b", "));
            }
        };
        *buffer
    }

    #[test_only]
    public fun assert_preorder_tree(tree: &Tree<u128>, byteString: vector<u8>) {
        std::debug::print(string::bytes(&preorder_string_with_values(tree)));
        assert!(*string::bytes(&preorder_string_with_values(tree)) == byteString, 0);
    }

    #[test(signer = @0x345)]
    fun test_is_empty_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        assert!(isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 0, 0);
        assert!(!containsKey(&tree, 10), 0);
        assert_preorder_tree(&tree, b"");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 1, 0);
        assert!(containsKey(&tree, 10), 0);
        assert_preorder_tree(&tree, b"10(B): [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_at_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 10, 100);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(containsKey(&tree, 10), 0);
        assert_preorder_tree(&tree, b"10(B): [10, 100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 8, 1);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 8), 0);
        assert_preorder_tree(&tree, b"10(B): [10], 8(B): [10, 1]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 12, 100);
        insert(&mut tree, 12, 1000);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 12), 0);
        assert_preorder_tree(&tree, b"10(B): [10], 12(B): [100, 1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 8), 0);
        assert!(*valueAtKey(&tree, 8) == 10, 0);
        assert!(*valueAtKey(&tree, 10) == 100, 0);
        assert_preorder_tree(&tree, b"10(B): [100], 8(B): [10]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_left_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 6, 1);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 8), 0);
        assert!(containsKey(&tree, 6), 0);
        assert!(*valueAtKey(&tree, 10) == 100, 0);
        assert!(*valueAtKey(&tree, 8) == 10, 0);
        assert!(*valueAtKey(&tree, 6) == 1, 0);
        assert_preorder_tree(&tree, b"10(B): [100], 8(B): [10], 6(B): [1]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 12), 0);
        assert!(*valueAtKey(&tree, 10) == 100, 0);
        assert!(*valueAtKey(&tree, 12) == 1000, 0);
        assert_preorder_tree(&tree, b"10(B): [100], 12(B): [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_right_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        insert(&mut tree, 14, 10000);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(containsKey(&tree, 10), 0);
        assert!(containsKey(&tree, 12), 0);
        assert!(containsKey(&tree, 14), 0);
        assert!(*valueAtKey(&tree, 10) == 100, 0);
        assert!(*valueAtKey(&tree, 12) == 1000, 0);
        assert!(*valueAtKey(&tree, 14) == 10000, 0);
        assert_preorder_tree(&tree, b"10(B): [100], 12(B): [1000], 14(B): [10000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_left_and_right_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 12, 1000);
        insert(&mut tree, 6, 5);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 4, 0);
        assert_preorder_tree(&tree, b"10(B): [100], 8(B): [10], 6(B): [5], 12(B): [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_peek(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!isEmpty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 1, 0);
        let (key, value) = peek<u128>(&tree);
        assert!(key == 10, 0);
        assert!(*value == 100, 0);
        move_to(&signer, tree)
    }

    /// NODE HELPERS

    fun leafNode<V: store + drop>(key: u128, value: V): Node<V> {
        Node {
            key,
            values:vector::singleton(value),
            leftChildNodeKey: 0,
            rigthChildNodeKey: 0,
            leftChildNodeKeyIsSet: false,
            rigthChildNodeKeyIsSet: false,
            isRed: false,
        }
    }

    fun isLeafNode<V: store + drop>(node: Node<V>): bool {
        !node.rigthChildNodeKeyIsSet && !node.leftChildNodeKeyIsSet
    }

    // NODE HELPERS TESTS

    #[test]
    fun test_is_leaf_node() {
        let node = leafNode<u128>(10, 100);
        assert!(isLeafNode(node), 0);
    }
}