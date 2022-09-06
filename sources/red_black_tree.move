module ferum_std::red_black_tree {
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
    const INVALID_ROTATION_NODES: u64 = 3;

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
        parentNodeKey: u128,
        leftChildNodeKey: u128,
        rightChildNodeKey: u128,

        // No null or optinal values, so we need to indicate whether the children have been set.
        parentNodeKeyIsSet: bool,
        leftChildNodeKeyIsSet: bool,
        rightChildNodeKeyIsSet: bool,

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

    public fun is_empty<V: store + drop>(tree: &Tree<V>): bool {
        tree.length == 0
    }

    public fun length<V: store + drop>(tree: &Tree<V>): u128 {
        tree.length
    }

    public fun peek<V: store + drop>(tree: &Tree<V>): (u128, &V) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        let rootNode = root_node(tree);
        let rootNodeFirstValue = vector::borrow<V>(&rootNode.values, 0);
        (tree.rootNodeKey, rootNodeFirstValue)
    }

    public fun contains_key<V: store + drop>(tree: &Tree<V>, key: u128): bool {
        table::contains(&tree.nodes, key)
    }

    public fun value_at<V: store + drop>(tree: &Tree<V>, key: u128): &V {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(contains_key(tree, key), KEY_NOT_SET);
        let node = node_with_key(tree, key);
        vector::borrow<V>(&node.values, 0)
    }

    public fun values_at<V: store + drop>(tree: &Tree<V>, key: u128): &vector<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(contains_key(tree, key), KEY_NOT_SET);
        let node = node_with_key(tree, key);
        &node.values
    }

    ///
    /// PRIVATE ACCESSORS
    ///

    fun root_node<V: store + drop>(tree: &Tree<V>): &Node<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        node_with_key(tree, tree.rootNodeKey)
    }

    fun node_with_key_mut<V: store + drop>(tree: &mut Tree<V>, key: u128): &mut Node<V> {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow_mut(&mut tree.nodes, key)
    }

    fun node_with_key<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow(&tree.nodes, key)
    }

    fun is_node_red<V: store + drop>(tree: &Tree<V>, key: u128): bool {
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        node_with_key(tree, key).isRed
    }

    fun has_left_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        node_with_key(tree, nodeKey).leftChildNodeKeyIsSet
    }

    fun has_right_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        node_with_key(tree, nodeKey).rightChildNodeKeyIsSet
    }

    ///
    /// INSERTION
    ///

    public fun insert<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V) {
        if (is_empty(tree)) {
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
        let node = node_with_key_mut(tree, nodeKey);
        if (key == node.key) {
            vector::push_back(&mut node.values, value);
            tree.length = tree.length + 1;
        } else if (key < node.key) {
            // Key is lower than the current value, so go towards left.
            if (node.leftChildNodeKeyIsSet) {
                insert_starting_at_node(tree, key, value, node.leftChildNodeKey);
            } else {
                // Insert new left child node.
                let newNode = leaf_node_with_parent(key, nodeKey, value);
                node.leftChildNodeKey = key;
                node.leftChildNodeKeyIsSet = true;
                freeze(node);
                table::add(&mut tree.nodes, key, newNode);
                tree.length = tree.length + 1;
            }
        } else if (key > node.key) {
            // Key is lower than the current value, so go towards right.
            if (node.rightChildNodeKeyIsSet) {
                insert_starting_at_node(tree, key, value, node.rightChildNodeKey);
            } else {
                // Insert new right child node.
                let newNode = leaf_node_with_parent(key, nodeKey, value);
                node.rightChildNodeKey = key;
                node.rightChildNodeKeyIsSet = true;
                freeze(node);
                table::add(&mut tree.nodes, key, newNode);
                tree.length = tree.length + 1;
            }
        }
    }

    fun leafNode<V: store + drop>(key: u128, value: V): Node<V> {
        Node {
            key,
            values:vector::singleton(value),
            parentNodeKey: 0,
            leftChildNodeKey: 0,
            rightChildNodeKey: 0,
            parentNodeKeyIsSet: false,
            leftChildNodeKeyIsSet: false,
            rightChildNodeKeyIsSet: false,
            isRed: false,
        }
    }

    fun leaf_node_with_parent<V: store + drop>(key: u128, parentKey: u128, value: V): Node<V> {
        let node = leafNode(key, value);
        node.parentNodeKey = parentKey;
        node.parentNodeKeyIsSet = true;
        node
    }

    ///
    /// ROTATIONS
    ///

    // Good example to follow is here, https://www.programiz.com/dsa/red-black-tree
    // We renaming x and y, with parent and child to make it a bit more concrete.
    fun rotate_left<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, childNodeKey: u128) {
        // 0. Check parent/child preconditions!
        {
            let parentNode = node_with_key(tree, parentNodeKey);
            let childNode = node_with_key(tree, childNodeKey);
            assert!(parentNode.rightChildNodeKey == childNodeKey, INVALID_ROTATION_NODES);
            assert!(childNode.parentNodeKey == parentNodeKey, INVALID_ROTATION_NODES);
        };

        // 1. If child has a left subtree, assign parent as the new parent of the left subtree of the child.
        if (has_left_child(tree, childNodeKey)) {
            let leftGrandchildNodeKey = node_with_key(tree, childNodeKey).leftChildNodeKey;
            let leftGrandchildNode = node_with_key_mut(tree, leftGrandchildNodeKey);
            // a. Fix the link upwards.
            leftGrandchildNode.parentNodeKey = parentNodeKey;
            // b. Parent node's right child now points to child's left substree.
            let parent = node_with_key_mut(tree, parentNodeKey);
            parent.rightChildNodeKey = leftGrandchildNodeKey;
            parent.rightChildNodeKeyIsSet = true;
        } else {
            // If the child node doesn't have a left subtree, we must disconnect the parent from the child.
            let parent = node_with_key_mut(tree, parentNodeKey);
            parent.rightChildNodeKeyIsSet = false;
        };

        // 2. Swap the parents; the child should point to the grandparent, if one exists (else, it's root).
        if (tree.rootNodeKey == parentNodeKey) {
            // The parent is root! The child must be promoted to root!
            let childNode = node_with_key_mut(tree, childNodeKey);
            childNode.parentNodeKeyIsSet = false;
            tree.rootNodeKey = childNodeKey;
        } else {
            let grandparentNodeKey = node_with_key(tree, parentNodeKey).parentNodeKey;
            let grandparentNode = node_with_key_mut(tree, grandparentNodeKey);
            if (grandparentNode.leftChildNodeKeyIsSet && grandparentNode.leftChildNodeKey == parentNodeKey) {
                grandparentNode.leftChildNodeKey = childNodeKey;
            } else {
                grandparentNode.rightChildNodeKey = childNodeKey;
            };
            let childNode = node_with_key_mut(tree, childNodeKey);
            childNode.parentNodeKey = grandparentNodeKey;
        };

        // 3. Make the child the new parent of the parent.
        {
            let childNode = node_with_key_mut(tree, childNodeKey);
            childNode.leftChildNodeKey = parentNodeKey;
            childNode.leftChildNodeKeyIsSet = true;
            let parentNode = node_with_key_mut(tree, parentNodeKey);
            parentNode.parentNodeKey = childNodeKey;
            parentNode.parentNodeKeyIsSet = true;
        };
    }

    fun rotate_right<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, childNodeKey: u128) {
        // 0. Check parent/child preconditions!
        {
            let parentNode = node_with_key(tree, parentNodeKey);
            let childNode = node_with_key(tree, childNodeKey);
            assert!(parentNode.leftChildNodeKey == childNodeKey, INVALID_ROTATION_NODES);
            assert!(childNode.parentNodeKey == parentNodeKey, INVALID_ROTATION_NODES);
        };
    }

    #[test(signer = @0x345)]
    fun test_rotate_left_with_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 4, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 14, 0);
        insert(&mut tree, 16, 0);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(B) 15 _ _: [0], 15(B) 10 14 16: [0], 16(B) 15 _ _: [0]");
        rotate_left(&mut tree, 10, 15);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) 15 4 14: [0], 14(B) 10 _ _: [0], 15(B) root 10 16: [0], 16(B) 15 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_left(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 4, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 14, 0);
        insert(&mut tree, 16, 0);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(B) 15 _ _: [0], 15(B) 10 14 16: [0], 16(B) 15 _ _: [0]");
        rotate_left(&mut tree, 15, 16);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 16: [0], 14(B) 15 _ _: [0], 15(B) 16 14 _: [0], 16(B) 10 15 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_rotate_left_with_incorrect_nodes(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 4, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 14, 0);
        insert(&mut tree, 16, 0);
        rotate_left(&mut tree, 10, 16);
        move_to(&signer, tree)
    }

    #[test_only]
    fun inorder<V: store + drop>(tree: &Tree<V>): vector<u128> {
        let inorderVector = &mut vector::empty<u128>();
        if (!is_empty(tree)) {
            let treeRootNode = tree.rootNodeKey;
            inorder_starting_at_node(tree, inorderVector, treeRootNode);
        };
        return *inorderVector
    }

    #[test_only]
    fun inorder_starting_at_node<V: store + drop>(tree: &Tree<V>, results: &mut vector<u128>, currentNodeKey: u128) {
        let currentNode = node_with_key(tree, currentNodeKey);
        if (currentNode.leftChildNodeKeyIsSet) {
            inorder_starting_at_node(tree, results, currentNode.leftChildNodeKey)
        };
        vector::push_back(results, currentNodeKey);
        if (currentNode.rightChildNodeKeyIsSet) {
            inorder_starting_at_node(tree, results, currentNode.rightChildNodeKey)
        };
    }

    #[test_only]
    fun inorder_string_with_tree(tree: &Tree<u128>): String {
        let inorderKeys = inorder(tree);
        let i = 0;
        let buffer = &mut string::utf8(b"");
        let len = vector::length(&inorderKeys);
        while (i < len) {
            let key = *vector::borrow(&inorderKeys, i);
            string::append(buffer, string_with_node(tree, key));
            i = i + 1;
            if (i < len) {
                string::append(buffer, string::utf8(b", "));
            }
        };
        *buffer
    }

    #[test_only]
    fun string_with_node(tree: &Tree<u128>, key: u128): String {
        let node = node_with_key(tree, key);
        let buffer = &mut string::utf8(b"");
        string::append(buffer, to_string_u128(key));
        string::append(buffer, string::utf8(if (is_node_red(tree, key)) b"(R)" else b"(B)"));
        if (node.parentNodeKeyIsSet) {
            string::append(buffer, string::utf8(b" "));
            string::append(buffer, to_string_u128(node.parentNodeKey));
        } else {
            string::append(buffer, string::utf8(b" root"));
        };
        if (node.leftChildNodeKeyIsSet) {
            string::append(buffer, string::utf8(b" "));
            string::append(buffer, to_string_u128(node.leftChildNodeKey));
        } else {
            string::append(buffer, string::utf8(b" _"));
        };
        if (node.rightChildNodeKeyIsSet) {
            string::append(buffer, string::utf8(b" "));
            string::append(buffer, to_string_u128(node.rightChildNodeKey));
        } else {
            string::append(buffer, string::utf8(b" _"));
        };
        string::append(buffer, string::utf8(b": ["));
        string::append(buffer, to_string_vector(values_at(tree, key), b", "));
        string::append(buffer, string::utf8(b"]"));
        *buffer
    }

    #[test_only]
    fun assert_inorder_tree(tree: &Tree<u128>, byteString: vector<u8>) {
        assert!(*string::bytes(&inorder_string_with_tree(tree)) == byteString, 0);
    }

    #[test_only]
    fun print_tree(tree: &Tree<u128>) {
        std::debug::print(string::bytes(&inorder_string_with_tree(tree)));
    }

    #[test_only]
    fun print_node(tree: &Tree<u128>, key: u128) {
        std::debug::print(string::bytes(&string_with_node(tree, key)));
    }

    #[test_only]
    fun assert_red_black_tree(tree: &Tree<u128>) {
        // Condition 1. The root node must be black!
        assert!(!is_node_red(tree, tree.rootNodeKey), 0)
        // TODO: Add the rest of the conditions!
    }

    #[test(signer = @0x345)]
    fun test_is_empty_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        assert!(is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 0, 0);
        assert!(!contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 1, 0);
        assert!(contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"10(B) root _ _: [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_at_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"10(B) root _ _: [10, 100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 8, 1);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert_inorder_tree(&tree, b"8(B) 10 _ _: [10, 1], 10(B) root 8 _: [10]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 12, 100);
        insert(&mut tree, 12, 1000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert_inorder_tree(&tree, b"10(B) root _ 12: [10], 12(B) 10 _ _: [100, 1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert!(*value_at(&tree, 8) == 10, 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert_inorder_tree(&tree, b"8(B) 10 _ _: [10], 10(B) root 8 _: [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_left_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 6, 1);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert!(contains_key(&tree, 6), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 8) == 10, 0);
        assert!(*value_at(&tree, 6) == 1, 0);
        assert_inorder_tree(&tree, b"6(B) 8 _ _: [1], 8(B) 10 6 _: [10], 10(B) root 8 _: [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 12) == 1000, 0);
        assert_inorder_tree(&tree, b"10(B) root _ 12: [100], 12(B) 10 _ _: [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_right_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        insert(&mut tree, 14, 10000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert!(contains_key(&tree, 14), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 12) == 1000, 0);
        assert!(*value_at(&tree, 14) == 10000, 0);
        assert_inorder_tree(&tree, b"10(B) root _ 12: [100], 12(B) 10 _ 14: [1000], 14(B) 12 _ _: [10000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_left_and_right_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 12, 1000);
        insert(&mut tree, 6, 5);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 4, 0);
        assert_inorder_tree(&tree, b"6(B) 8 _ _: [5], 8(B) 10 6 _: [10], 10(B) root 8 12: [100], 12(B) 10 _ _: [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_peek(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(length<u128>(&tree) == 1, 0);
        let (key, value) = peek<u128>(&tree);
        assert!(key == 10, 0);
        assert!(*value == 100, 0);
        move_to(&signer, tree)
    }
}