///
///
///
/// Good Reading
///   https://www.geeksforgeeks.org/red-black-tree-set-3-delete-2/ but keep in mind that the code example has a few bus.
///   https://gist.github.com/iEgit/e8574798870663d5fa1d159308a3ef62 red/black implementation via C++.
///   https://www.programiz.com/dsa/red-black-tree but keep in mind that we don't have null nodes, which makes a lot of
///     their code examples impossible to adopt with our code.
///
/// Testing Tools
///  Binary to ASCI Converter: https://www.duplichecker.com/ascii-to-text.php
///  Red/Black Tree Visualizer: https://www.cs.usfca.edu/~galles/visualization/RedBlack.html (although they use left max
///  sucessor replacement strategy on deletion and we use right min.
///
module ferum_std::red_black_tree {
    use std::vector;
    use aptos_std::table;
    #[test_only]
    use ferum_std::test_utils::{to_string_u128, u128_from_string};
    #[test_only]
    use ferum_std::test_utils::to_string_vector;
    #[test_only]
    use std::string::{Self, String};

    //
    // ERRORS
    //
    const TREE_IS_EMPTY: u64 = 0;
    const KEY_NOT_SET: u64 = 1;
    const NODE_NOT_FOUND: u64 = 2;
    const INVALID_ROTATION_NODES: u64 = 3;
    const INVALID_KEY_ACCESS: u64 = 4;
    const INVALID_SUCCESSOR_OPERATION: u64 = 5;
    const INVALID_DELETION_OPERATION: u64 = 6;
    const INVALID_OUTGOING_SWAP_EDGE_DIRECTION: u64 = 7;
    const ONLY_LEAF_NODES_CAN_BE_ADDED: u64 = 8;
    const INVALID_FIX_DOUBLE_RED_OPERATION: u64 = 9;

    //
    // STRUCTS
    //
    struct Tree<V: store> has key {
        // Since the tree supports duplicate values, key count is different than value count.
        // Also, since the way we implement R/B doesn't have null leaf nodes, key count equals node count.
        keyCount: u128,
        // Counts the total number of values in the tree; valueCount >= keyCount.
        valueCount: u128,
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
        Tree<V> { keyCount: 0, valueCount: 0, rootNodeKey: 0, nodes: table::new<u128, Node<V>>()}
    }

    ///
    /// PUBLIC ACCESSORS
    ///

    public fun is_empty<V: store + drop>(tree: &Tree<V>): bool {
        tree.keyCount == 0
    }

    public fun key_count<V: store + drop>(tree: &Tree<V>): u128 {
        tree.keyCount
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
        let node = get_node(tree, key);
        vector::borrow<V>(&node.values, 0)
    }

    public fun values_at<V: store + drop>(tree: &Tree<V>, key: u128): &vector<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(contains_key(tree, key), KEY_NOT_SET);
        let node = get_node(tree, key);
        &node.values
    }

    ///
    /// PRIVATE ACCESSORS
    ///

    fun root_node<V: store + drop>(tree: &Tree<V>): &Node<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        get_node(tree, tree.rootNodeKey)
    }

    fun get_node_mut<V: store + drop>(tree: &mut Tree<V>, key: u128): &mut Node<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow_mut(&mut tree.nodes, key)
    }

    fun get_node<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow(&tree.nodes, key)
    }

    fun is_left_child_via_keys<V: store + drop>(tree: &Tree<V>, childNodeKey: u128, parentNodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, childNodeKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentNodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, parentNodeKey)) {
            let parentNode = get_node(tree, parentNodeKey);
            return parentNode.leftChildNodeKey == childNodeKey
        };
        return false
    }

    fun is_left_child<V: store + drop>(child: &Node<V>, parent: &Node<V>): bool {
        parent.leftChildNodeKeyIsSet &&
            parent.leftChildNodeKey == child.key &&
            child.parentNodeKeyIsSet &&
            child.parentNodeKey == parent.key
    }

    fun has_left_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node(tree, nodeKey).leftChildNodeKeyIsSet
    }

    fun left_child_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let leftChildNodeKey = get_node(tree, nodeKey).leftChildNodeKey;
        get_node_mut(tree, leftChildNodeKey)
    }

    fun is_right_child_via_keys<V: store + drop>(tree: &Tree<V>, childNodeKey: u128, parentNodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, childNodeKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentNodeKey), NODE_NOT_FOUND);
        if (has_right_child(tree, parentNodeKey)) {
            let parentNode = get_node(tree, parentNodeKey);
            return parentNode.rightChildNodeKey == childNodeKey
        };
        return false
    }

    fun is_right_child<V: store + drop>(child: &Node<V>, parent: &Node<V>): bool {
        parent.rightChildNodeKeyIsSet &&
            parent.rightChildNodeKey == child.key &&
            child.parentNodeKeyIsSet &&
            child.parentNodeKey == parent.key
    }

    fun has_right_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node(tree, nodeKey).rightChildNodeKeyIsSet
    }

    fun right_child_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let rightChildNodeKey = get_node(tree, nodeKey).rightChildNodeKey;
        get_node_mut(tree, rightChildNodeKey)
    }

    fun right_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        get_node(tree, nodeKey).rightChildNodeKey
    }

    fun left_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        get_node(tree, nodeKey).leftChildNodeKey
    }

    fun is_root_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        tree.rootNodeKey == nodeKey
    }

    fun is_leaf_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        !has_left_child(tree, nodeKey) && !has_right_child(tree, nodeKey)
    }

    fun set_root_node<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = get_node_mut(tree, nodeKey);
        node.parentNodeKeyIsSet = false;
        tree.rootNodeKey = nodeKey;
    }

    fun set_left_child<V: store + drop>(tree: &mut Tree<V>, parentKey: u128, childKey: u128) {
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(!has_left_child(tree, parentKey), INVALID_KEY_ACCESS);
        let parentNode = get_node_mut(tree, parentKey);
        parentNode.leftChildNodeKey = childKey;
        parentNode.leftChildNodeKeyIsSet = true;
        let childNode = get_node_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_left_child<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, nodeKey)) {
            let childNode = left_child_mut(tree, nodeKey);
            childNode.parentNodeKeyIsSet = false;
            let node = get_node_mut(tree, nodeKey);
            node.leftChildNodeKeyIsSet = false;
        };
    }

    fun set_right_child<V: store + drop>(tree: &mut Tree<V>, parentKey: u128, childKey: u128) {
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        let parentNode = get_node_mut(tree, parentKey);
        parentNode.rightChildNodeKey = childKey;
        parentNode.rightChildNodeKeyIsSet = true;
        let childNode = get_node_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_right_child<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_right_child(tree, nodeKey)) {
            let childNode = right_child_mut(tree, nodeKey);
            childNode.parentNodeKeyIsSet = false;
            let node = get_node_mut(tree, nodeKey);
            node.rightChildNodeKeyIsSet = false;
        };
    }

    fun has_parent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = get_node(tree, nodeKey);
        node.parentNodeKeyIsSet
    }

    fun set_parent<V: store + drop>(tree: &mut Tree<V>, childKey: u128, parentKey: u128) {
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        assert!(!has_parent(tree, childKey), INVALID_KEY_ACCESS);
        let childNode = get_node_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_parent<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        if (is_left_child_via_keys(tree, nodeKey, parentNodeKey)) {
            unset_left_child(tree, parentNodeKey);
        } else {
            unset_right_child(tree, parentNodeKey);
        };
    }

    fun parent_node_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let node = get_node(tree, nodeKey);
        node.parentNodeKey
    }

    fun parent_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentKey = parent_node_key(tree, nodeKey);
        get_node_mut(tree, parentKey)
    }

    fun unset_edges<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        let node = get_node_mut(tree, nodeKey);

        let parentKey = node.parentNodeKey;
        let parentSet = node.parentNodeKeyIsSet;
        let leftChildKey = node.leftChildNodeKey;
        let leftChildSet = node.leftChildNodeKeyIsSet;
        let rightChildKey = node.rightChildNodeKey;
        let rightChildSet = node.rightChildNodeKeyIsSet;

        // Node mutations.
        node.parentNodeKey = 0;
        node.parentNodeKeyIsSet = false;
        node.leftChildNodeKey = 0;
        node.leftChildNodeKeyIsSet = false;
        node.rightChildNodeKey = 0;
        node.rightChildNodeKeyIsSet = false;

        // Neighbour node mutations.
        if (parentSet) {
            let parent = get_node_mut(tree, parentKey);
            if (parent.leftChildNodeKeyIsSet && nodeKey == parent.leftChildNodeKey) {
                parent.leftChildNodeKeyIsSet = false;
                parent.leftChildNodeKey = 0;
            } else {
                parent.rightChildNodeKeyIsSet = false;
                parent.rightChildNodeKey = 0;
            }
        };
        if (rightChildSet) {
            let rightChild = get_node_mut(tree, rightChildKey);
            rightChild.parentNodeKeyIsSet = false;
            rightChild.parentNodeKey = 0;
        };
        if (leftChildSet) {
            let leftChild = get_node_mut(tree, leftChildKey);
            leftChild.parentNodeKeyIsSet = false;
            leftChild.parentNodeKey = 0;
        };
    }

    fun has_grandparent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = get_node(tree, nodeKey);
        if (node.parentNodeKeyIsSet) {
            let parent = get_node(tree, node.parentNodeKey);
            return parent.parentNodeKeyIsSet
        };
        return false
    }

    fun has_sibiling<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_parent(tree, nodeKey)) {
            let parentNodeKey = parent_node_key(tree, nodeKey);
            let parent = get_node(tree, parentNodeKey);
            return parent.leftChildNodeKeyIsSet && parent.rightChildNodeKeyIsSet
        };
        false
    }

    fun sibiling_node_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_sibiling(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        let parent = get_node(tree, parentNodeKey);
        if (parent.leftChildNodeKey == nodeKey) {
            parent.rightChildNodeKey
        } else {
            parent.leftChildNodeKey
        }
    }

    fun grandparent_node_key<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): u128 {
        assert!(has_grandparent(tree, nodeKey), INVALID_KEY_ACCESS);
        let node = get_node(tree, nodeKey);
        let parent = get_node(tree, node.parentNodeKey);
        parent.parentNodeKey
    }

    // Return the key of the node that would replace the node if it's deleted.
    fun get_successor<V: store + drop>(tree: &Tree<V>, nodeKey: u128): &Node<V> {
        let node = get_node(tree, nodeKey);
        assert!(node.leftChildNodeKeyIsSet || node.rightChildNodeKeyIsSet, 0);

        if (node.rightChildNodeKeyIsSet) {
            let rightChildKey = node.rightChildNodeKey;
            get_min_node_start_at_node(tree, rightChildKey)
        } else {
            let leftChildKey = node.leftChildNodeKey;
            get_max_node_start_at_node(tree, leftChildKey)
        }
    }

    fun get_max_node_start_at_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): &Node<V> {
        let node = get_node(tree, nodeKey);
        while (node.rightChildNodeKeyIsSet) {
            let rightChildKey = node.rightChildNodeKey;
            node = get_node(tree, rightChildKey);
        };
        node
    }

    fun get_min_node_start_at_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): &Node<V> {
        let node = get_node(tree, nodeKey);
        while (node.leftChildNodeKeyIsSet) {
            let leftChildKey = node.leftChildNodeKey;
            node = get_node(tree, leftChildKey);
        };
        node
    }

    ///
    /// COLOR ACCESSORS
    ///

    fun is_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node(tree, nodeKey).isRed
    }

    fun is_black<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        !is_red(tree, nodeKey)
    }

    fun is_parent_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        let parentNode = get_node(tree, parentNodeKey);
        parentNode.isRed
    }

    fun is_right_child_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let rightChildKey = right_child_key(tree, nodeKey);
        is_red(tree, rightChildKey)
    }

    fun is_left_child_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let leftChildKey = left_child_key(tree, nodeKey);
        is_red(tree, leftChildKey)
    }

    fun has_red_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        has_left_child(tree, nodeKey) && is_left_child_red(tree, nodeKey) ||
            has_right_child(tree, nodeKey) && is_right_child_red(tree, nodeKey)
    }

    ///
    /// COLOR MARKERS
    ///

    fun mark_red<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node_mut(tree, nodeKey).isRed = true;
    }

    fun mark_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node_mut(tree, nodeKey).isRed = false;
    }

    fun mark_color<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128, isRed: bool) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node_mut(tree, nodeKey).isRed = isRed;
    }

    fun mark_children_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        mark_children_color(tree, nodeKey, false);
    }

    fun mark_children_red<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        mark_children_color(tree, nodeKey, true);
    }

    fun mark_children_color<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128, isRed: bool) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, nodeKey)) {
            let leftNode = left_child_mut(tree, nodeKey);
            leftNode.isRed = isRed;
        };
        if (has_right_child(tree, nodeKey)) {
            let rightNode = right_child_mut(tree, nodeKey);
            rightNode.isRed = isRed;
        };
    }

    fun mark_sibiling_red<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_sibiling(tree, nodeKey), INVALID_KEY_ACCESS);
        let sibilingNodeKey = sibiling_node_key(tree, nodeKey);
        let sibilingNode = get_node_mut(tree, sibilingNodeKey);
        sibilingNode.isRed = true
    }

    fun mark_parent_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        let parentNode = get_node_mut(tree, parentNodeKey);
        parentNode.isRed = false;
    }

    fun mark_grandparent_red<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_grandparent(tree, nodeKey), INVALID_KEY_ACCESS);
        let grandparentNodeKey = grandparent_node_key(tree, nodeKey);
        let grandparentNode = get_node_mut(tree, grandparentNodeKey);
        grandparentNode.isRed = true;
    }

    //
    // INSERTION
    //

    public fun insert<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V) {
        if (is_empty(tree)) {
            // If the tree is empty, instantiate a new root!
            let rootNode = leaf_node<V>(key, value);
            // Root node is always black!
            rootNode.isRed = false;
            tree.rootNodeKey = key;
            add_new_leaf_node(tree, key, rootNode);
        } else {
            // Otherwise, recursively insert starting at the root node.
            let rootNodeKey = tree.rootNodeKey;
            insert_starting_at_node(tree, key, value, rootNodeKey);
        };
    }

    fun insert_starting_at_node<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V, nodeKey: u128) {
        let node = get_node_mut(tree, nodeKey);
        if (key == node.key) {
            // Because this is a duplicate key, only increase value count!
            vector::push_back(&mut node.values, value);
            tree.valueCount = tree.valueCount + 1;
        } else if (key < node.key) {
            // Key is lower than the current value, so go towards left.
            if (node.leftChildNodeKeyIsSet) {
                insert_starting_at_node(tree, key, value, node.leftChildNodeKey);
            } else {
                // Insert new left child node.
                let newNode = leaf_node_with_parent(key, nodeKey, value);
                node.leftChildNodeKey = key;
                node.leftChildNodeKeyIsSet = true;
                add_new_leaf_node(tree, key, newNode);

                // In case any red/black invariants were broken, fix it up!
                fix_double_red(tree, key)
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
                add_new_leaf_node(tree, key, newNode);

                // In case any red/black invariants were broken, fix it up!
                fix_double_red(tree, key)
            }
        }
    }

    fun leaf_node<V: store + drop>(key: u128, value: V): Node<V> {
        Node {
            key,
            values:vector::singleton(value),
            parentNodeKey: 0,
            leftChildNodeKey: 0,
            rightChildNodeKey: 0,
            parentNodeKeyIsSet: false,
            leftChildNodeKeyIsSet: false,
            rightChildNodeKeyIsSet: false,
            // By default, all new nodes are red! Although remember that root node must always be black!
            isRed: true,
        }
    }

    fun leaf_node_with_parent<V: store + drop>(key: u128, parentKey: u128, value: V): Node<V> {
        let node = leaf_node(key, value);
        node.parentNodeKey = parentKey;
        node.parentNodeKeyIsSet = true;
        node
    }

    fun add_new_leaf_node<V: store + drop>(tree: &mut Tree<V>, key: u128, node: Node<V>) {
        assert!(vector::length(&node.values) == 1, ONLY_LEAF_NODES_CAN_BE_ADDED);
        table::add(&mut tree.nodes, key, node);
        tree.keyCount = tree.keyCount + 1;
        tree.valueCount = tree.valueCount + 1;
    }

    //
    // DELETIONS
    //

    public fun delete<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (!table::contains(&tree.nodes, nodeKey)) {
            // Nothing to delete.
            return
        };

        if (tree.length == 1) {
            // Leaf node that is also the root. Just remove the node from the tree.
            table::remove(&mut tree.nodes, nodeKey);
            tree.length = 0;
            tree.rootNodeKey = 0;
            return
        };

        let node = get_node(tree, nodeKey);
        if (!node.leftChildNodeKeyIsSet && !node.rightChildNodeKeyIsSet) {
            // A leaf node. Can't be root because we already accounted for that case above.
            remove_leaf_node(tree, nodeKey);
        } else {
            // Not a leaf node. First swap with successor. This makes the node a leaf node.
            // So we can delete it in the same way as above.
            let nodeKey = node.key;
            swap_with_successor(tree, nodeKey);

            // It's not gauranteed that the node is a leaf node at this point because multiple successor swaps might
            // be neccesary. We can just call delete again to cover that case.
            delete(tree, nodeKey);
        }
    }

    fun remove_leaf_node<V: store + drop>(tree: &mut Tree<V>, key: u128) {
        let node = get_node(tree, key);
        assert!(!node.leftChildNodeKeyIsSet, 0);
        assert!(!node.rightChildNodeKeyIsSet, 0);
        assert!(node.parentNodeKeyIsSet, 0);

        // If the node is red, removing it will not have affected tree invariants.
        // If the node is black, we need to account for the missing black. We do this
        // by marking the node to be deleted as double black, which we then fix via `fix_double_black`.
        if (!node.isRed) {
            fix_double_black(tree, key);
        };

        // After fixing the double black, we can actually delete the node.

        // Remove node from table.
        let node = table::remove(&mut tree.nodes, key);
        tree.length = tree.length - 1;

        // Disconnect node from parent.
        let parentKey = node.parentNodeKey;
        let parent = get_node_mut(tree, parentKey);
        if (parent.leftChildNodeKeyIsSet && parent.leftChildNodeKey == node.key) {
            parent.leftChildNodeKeyIsSet = false
        } else {
            parent.rightChildNodeKeyIsSet = false
        };
    }

    fun fix_double_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (is_root_node(tree, nodeKey)) {
            return
        };
        let parentNodeKey = parent_node_key(tree, nodeKey);
        if (has_sibiling(tree, nodeKey)) {
            let sibilingNodeKey = sibiling_node_key(tree, nodeKey);
            // 3.2 (c): If sibling is red, perform a rotation to move old sibling up, recolor the old sibling and
            // parent. The new sibling is always black (See the below diagram). This mainly converts the tree to black
            // sibling case (by rotation) and leads to case (a) or (b). This case can be divided in two subcases.
            if (is_red(tree, sibilingNodeKey)) { // Sibiling is red!
                mark_red(tree, parentNodeKey);
                mark_black(tree, sibilingNodeKey);
                if (is_left_child_via_keys(tree, sibilingNodeKey, parentNodeKey)) {
                    rotate_right(tree, parentNodeKey, sibilingNodeKey);
                } else {
                    rotate_left(tree, parentNodeKey, sibilingNodeKey);
                };
                fix_double_black(tree, nodeKey);
            } else { // Sibiling is black!
                // 3.2 (a): If sibling s is black and at least one of sibling's children is red, perform rotation(s).
                // Let the red child of s be r. This case can be divided in four subcases depending upon positions of
                // s and r.
                if (has_red_child(tree, sibilingNodeKey)) { // At least one of sibiling's children is red!
                    if (is_left_child_via_keys(tree, sibilingNodeKey, parentNodeKey)) { // Sibiling is the left child!
                        if (has_left_child(tree, sibilingNodeKey) && is_left_child_red(tree, sibilingNodeKey)) {
                            // 3.2.a (i) Left Left Case (s is left child of its parent and r is left child of s or both
                            // children of s are red).
                            let isSibilingRed = is_red(tree, sibilingNodeKey);
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingLeftChildNodeKey = left_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingLeftChildNodeKey, isSibilingRed);
                            mark_color(tree, sibilingNodeKey, isParentRed);
                            rotate_right(tree, parentNodeKey, sibilingNodeKey);
                        } else {
                            // 3.2.a (ii): Left Right Case (s is left child of its parent and r is right child).
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingRightChildNodeKey = right_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingRightChildNodeKey, isParentRed);
                            rotate_left(tree, sibilingNodeKey, sibilingRightChildNodeKey);
                            rotate_right(tree, parentNodeKey, sibilingRightChildNodeKey);
                        }
                    } else { // sibiling is the right child!
                        if (has_right_child(tree, sibilingNodeKey) && is_right_child_red(tree, sibilingNodeKey)) {
                            // 3.2.a (iii) Right Right Case (s is right child of its parent and r is right child of s
                            // or both children of s are red).
                            let isParentRed = is_red(tree, parentNodeKey);
                            let isSibilingRed = is_red(tree, sibilingNodeKey);
                            let sibilingRightChildKey = right_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingRightChildKey, isSibilingRed);
                            mark_color(tree, sibilingNodeKey, isParentRed);
                            rotate_left(tree, parentNodeKey, sibilingNodeKey);
                        } else {
                            // 3.2.a (iv): Right Left Case (s is right child of its parent and r is left child of s).
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingLeftChildNodeKey = left_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingLeftChildNodeKey, isParentRed);
                            rotate_right(tree, sibilingNodeKey, sibilingLeftChildNodeKey);
                            rotate_left(tree, parentNodeKey, sibilingLeftChildNodeKey);
                        }
                    };
                    mark_black(tree, parentNodeKey);
                } else { // Two black children!
                    mark_red(tree, sibilingNodeKey);
                    if (is_black(tree, parentNodeKey)) {
                        fix_double_black(tree, parentNodeKey);
                    } else {
                        mark_black(tree, parentNodeKey);
                    }
                }
            }
        } else {
            // The current double black node doesn't have a sibiling, so we can't fix the problem here. Let's give it
            // to our parents, like we always do. Remember, we have checked that we're not the root node, so the parent
            // node must exist!
            let parentNodeKey = parent_node_key(tree, nodeKey);
            fix_double_black(tree, parentNodeKey);
        }
    }

    fun drop_node<V: store + drop>(tree: &mut Tree<V>, key: u128) {
        assert!(!is_empty(tree), INVALID_DELETION_OPERATION);
        if (has_parent(tree, key)) {
            unset_parent(tree, key);
        };
        table::remove(&mut tree.nodes, key);
        tree.keyCount = tree.keyCount - 1
    }

    ///
    /// SUCCESSOR SWAPPING
    ///

    const EDGE_LEFT_CHILD: u8 = 1;
    const EDGE_RIGHT_CHILD: u8  = 2;
    const EDGE_PARENT_LEFT: u8  = 3;
    const EDGE_PARENT_RIGHT: u8  = 4;

    struct OutgoingEdge has copy, drop {
        target: u128,
        direction: u8,
    }

    fun get_outgoing_edges<V: store + drop>(tree: &Tree<V>, node: &Node<V>): vector<OutgoingEdge> {
        let outgoingEdges = &mut vector::empty<OutgoingEdge>();
        if (node.rightChildNodeKeyIsSet) {
            vector::push_back(outgoingEdges, OutgoingEdge { target: node.rightChildNodeKey, direction: EDGE_RIGHT_CHILD });
        };
        if (node.leftChildNodeKeyIsSet) {
            vector::push_back(outgoingEdges, OutgoingEdge { target: node.leftChildNodeKey, direction: EDGE_LEFT_CHILD });
        };
        if (node.parentNodeKeyIsSet) {
            let parent = get_node(tree, node.parentNodeKey);
            if (is_left_child(node, parent)) {
                vector::push_back(outgoingEdges, OutgoingEdge { target: parent.key, direction: EDGE_PARENT_LEFT });
            } else {
                vector::push_back(outgoingEdges, OutgoingEdge { target: parent.key, direction: EDGE_PARENT_RIGHT });
            };
        };
        *outgoingEdges
    }

    fun apply_edges<V: store + drop>(
        tree: &mut Tree<V>,
        edges: &vector<OutgoingEdge>,
        nodeKey: u128,
        originalNodeKey: u128,
    ) {
        let i = 0;
        while (i < vector::length(edges)) {
            let edge = vector::borrow(edges, i);
            let target = if (edge.target == nodeKey) originalNodeKey else edge.target;

            let node = get_node_mut(tree, nodeKey);
            if (edge.direction == EDGE_LEFT_CHILD) {
                node.leftChildNodeKey = target;
                node.leftChildNodeKeyIsSet = true;
                let leftChild = table::borrow_mut(&mut tree.nodes, target);
                leftChild.parentNodeKey = nodeKey;
                leftChild.parentNodeKeyIsSet = true;
            } else if (edge.direction == EDGE_RIGHT_CHILD) {
                node.rightChildNodeKey = target;
                node.rightChildNodeKeyIsSet = true;
                let rightChild = table::borrow_mut(&mut tree.nodes, target);
                rightChild.parentNodeKey = nodeKey;
                rightChild.parentNodeKeyIsSet = true;
            } else if (edge.direction == EDGE_PARENT_LEFT) {
                node.parentNodeKey = target;
                node.parentNodeKeyIsSet = true;
                let parent = table::borrow_mut(&mut tree.nodes, target);
                parent.leftChildNodeKey = nodeKey;
                parent.leftChildNodeKeyIsSet = true;
            } else if (edge.direction == EDGE_PARENT_RIGHT) {
                node.parentNodeKey = target;
                node.parentNodeKeyIsSet = true;
                let parent = table::borrow_mut(&mut tree.nodes, target);
                parent.rightChildNodeKey = nodeKey;
                parent.rightChildNodeKeyIsSet = true;
            } else {
                assert!(false, INVALID_OUTGOING_SWAP_EDGE_DIRECTION);
            };
            i = i + 1;
        }
    }

    // Swapping nodes is annoying because we need to update all references that other nodes are making to the nodes
    // we are swapping.
    fun swap_with_successor<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(has_left_child(tree, nodeKey) || has_right_child(tree, nodeKey), INVALID_SUCCESSOR_OPERATION);
        let successor = get_successor(tree, nodeKey);
        let successorKey = successor.key;
        let isSuccessorRed = successor.isRed;

        let successorOutgoingEdges = get_outgoing_edges(tree, successor);
        let node = get_node(tree, nodeKey);
        let nodeOutgoingEdges = get_outgoing_edges(tree, node);

        unset_edges(tree, nodeKey);
        unset_edges(tree, successorKey);
        apply_edges(tree, &successorOutgoingEdges, nodeKey, successorKey);
        apply_edges(tree, &nodeOutgoingEdges, successorKey, nodeKey);

        if (tree.rootNodeKey == nodeKey) {
            tree.rootNodeKey = successorKey;
        };
        let isNodeRed = is_red(tree, nodeKey);

        mark_color(tree, nodeKey, isSuccessorRed);
        mark_color(tree, successorKey, isNodeRed);
    }

    // After an insertion of a red node, its possible that we have a red node with a red child,
    // which violates the properties of a red black tree. `fix_double_red` corrects the problem.
    //
    // There are four possible configurations in this situation
    // (GN = grandparent node, PN = parent node, CN = current node):
    //
    // Case 1:
    //
    //      (Blk) GN                       (Red) PN
    //           / \                            / \
    //    (Red) PN   T4   transformed          /   \
    //         / \        ---------->   (Blk) CN   GN (Blk)
    //  (Red) CN   T3                        / \   / \
    //       / \                            T1 T2 T3 T4
    //     T1   T2
    //
    // Case 2:
    //
    //    (Blk) GN                          (Red) CN
    //         / \                               / \
    //  (Red) PN   T4      transformed          /   \
    //       / \           ---------->   (Blk) PN   GN (Blk)
    //     T1   CN (Red)                      / \   / \
    //         / \                           T1 T2 T3 T4
    //       T2   T3
    //
    // Case 3:
    //
    //         GN (Blk)                      (Red) CN
    //        / \                                 / \
    //      T1   PN (Red)   transformed          /   \
    //          / \         ---------->   (Blk) GN   PN (Blk)
    //   (Red) CN  T4                          / \   / \
    //        / \                             T1 T2 T3 T4
    //      T2   T3
    //
    // Case 4:
    //
    //    GN (Blk)                       (Red) PN
    //   / \                                  / \
    // T1   PN (Red)     transformed         /   \
    //     / \          ---------->   (Blk) GN   CN (Blk)
    //   T2   CN (Red)                     / \   / \
    //       / \                          T1 T2 T3 T4
    //     T3   T4
    //
    // where T1, T2, T3, and T4 are subtrees (possibly empty). Note that since the root node is always black,
    // we will always have a black grandparent.
    //
    // The root after these transformations may still have a red parent. So the process repeats
    // until that's no longer the case.
    //
    // If the root of the tree is red, it is colored black.
    //
    fun fix_double_red<V: store + drop>(tree: &mut Tree<V>, currentNodeKey: u128) {
        // Continue while the parent of the current node is red. Keep in mind that root is always black, so
        // this condition only applies to 3rd layers and below (ie we will eventually terminate).
        while (true) {
            let currentNode = get_node(tree, currentNodeKey);
            if (!currentNode.isRed) {
                break
            };
            if (!currentNode.parentNodeKeyIsSet) {
                break
            };
            let parent = get_node(tree, currentNode.parentNodeKey);
            let parentKey = parent.key;
            if (!parent.isRed) {
                // If the parent is not red, there is no longer a double red and we can exit.
                break
            };
            // If there is no grandparent, the parent is the root of the tree and we screwed up somewhere
            // because the root of the tree is red.
            assert!(parent.parentNodeKeyIsSet, INVALID_FIX_DOUBLE_RED_OPERATION);

            let grandparent = get_node(tree, parent.parentNodeKey);
            let grandparentKey = grandparent.key;
            assert!(!grandparent.isRed, 0);

            // Split based on if the current parent is on the left or on the right side of the grandparent.
            if (is_left_child(parent, grandparent) && is_left_child(currentNode, parent)) {
                // Case 1:
                //
                //      (Blk) GN                       (Red) PN
                //           / \                            / \
                //    (Red) PN   T4   transformed          /   \
                //         / \        ---------->   (Blk) CN   GN (Blk)
                //  (Red) CN   T3                        / \   / \
                //       / \                            T1 T2 T3 T4
                //     T1   T2
                //
                rotate_right(tree, grandparentKey, parentKey);
                get_node_mut(tree, currentNodeKey).isRed = false;
                currentNodeKey = parentKey;
                continue
            } else if (is_left_child(parent, grandparent) && is_right_child(currentNode, parent)) {
                // Case 2:
                //
                //    (Blk) GN                          (Red) CN
                //         / \                               / \
                //  (Red) PN   T4      transformed          /   \
                //       / \           ---------->   (Blk) PN   GN (Blk)
                //     T1   CN (Red)                      / \   / \
                //         / \                           T1 T2 T3 T4
                //       T2   T3
                //
                rotate_left(tree, parentKey, currentNodeKey);
                rotate_right(tree, grandparentKey, currentNodeKey);
                get_node_mut(tree, parentKey).isRed = false;
                // Current node stays the same.
                continue
            } else if (is_right_child(parent, grandparent) && is_left_child(currentNode, parent)) {
                // Case 3:
                //
                //         GN (Blk)                      (Red) CN
                //        / \                                 / \
                //      T1   PN (Red)   transformed          /   \
                //          / \         ---------->   (Blk) GN   PN (Blk)
                //   (Red) CN  T4                          / \   / \
                //        / \                             T1 T2 T3 T4
                //      T2   T3
                //
                rotate_right(tree, parentKey, currentNodeKey);
                rotate_left(tree, grandparentKey, currentNodeKey);
                get_node_mut(tree, parentKey).isRed = false;
                // Current node stays the same.
                continue
            } else if (is_right_child(parent, grandparent) && is_right_child(currentNode, parent)) {
                // Case 4:
                //
                //    GN (Blk)                       (Red) PN
                //   / \                                  / \
                // T1   PN (Red)     transformed         /   \
                //     / \           ---------->  (Blk) GN   CN (Blk)
                //   T2   CN (Red)                     / \   / \
                //       / \                          T1 T2 T3 T4
                //     T3   T4
                rotate_left(tree, grandparentKey, parentKey);
                get_node_mut(tree, currentNodeKey).isRed = false;
                currentNodeKey = parentKey;
                continue
            }
        };

        // Color root node black if it's red.
        let rootNodeKey = tree.rootNodeKey;
        let root = get_node_mut(tree, rootNodeKey);
        root.isRed = false;
    }

    ///
    /// ROTATIONS
    ///

    // Performs a right rotation centered around a parent node (PN) and a child node (CN):
    //
    //      PN                         CN
    //     / \                        / \
    //    CN  T3      rotated       T1   PN
    //   / \        ---------->          / \
    //  T1   T2                         T2  T3
    //
    // where T1, T2, and T3 are subtrees (possibly empty).
    // If CN is not the right child of the parent, will throw an error.
    fun rotate_right<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, nodeKey: u128) {
        if (tree.rootNodeKey == parentNodeKey) {
            tree.rootNodeKey = nodeKey;
        };

        // First process the node mutations.
        let newLeftChild = 0u128;
        let newLeftChildIsSet = false;
        {
            // Save grandparent information for later.
            let parent = get_node(tree, parentNodeKey);
            let grandparentKey = parent.parentNodeKey;
            let grandparentKeyIsSet = parent.parentNodeKeyIsSet;
            // Modify grandparent to point to current node.
            if (grandparentKeyIsSet) {
                let grandparent = get_node_mut(tree, grandparentKey);
                if (grandparent.leftChildNodeKey == parentNodeKey) {
                    grandparent.leftChildNodeKey = nodeKey;
                } else {
                    grandparent.rightChildNodeKey = nodeKey;
                }
            };

            let node = get_node_mut(tree, nodeKey);

            // Validate node properties.
            assert!(node.parentNodeKeyIsSet && node.parentNodeKey == parentNodeKey, INVALID_ROTATION_NODES);

            // Disconnect from parent.
            node.parentNodeKeyIsSet = false;

            // If node has a right subtree, it becomes the left child of the parent.
            // We save this information for later.
            if (node.rightChildNodeKeyIsSet) {
                let rightChildNode = get_node_mut(tree, node.rightChildNodeKey);
                rightChildNode.parentNodeKey = parentNodeKey;
                rightChildNode.parentNodeKeyIsSet = true;
                newLeftChild = rightChildNode.key;
                newLeftChildIsSet = true;
            };

            // Re-borrow.
            let node = get_node_mut(tree, nodeKey);

            // Set parent of node to be its grandparent (using info we saved above).
            node.parentNodeKey = grandparentKey;
            node.parentNodeKeyIsSet = grandparentKeyIsSet;

            // Set right child of node to be the parent.
            node.rightChildNodeKey = parentNodeKey;
            node.rightChildNodeKeyIsSet = true;
        };

        // Now process the parent mutations.
        {
            let parent = get_node_mut(tree, parentNodeKey);

            // Validate parent properties.
            assert!(parent.leftChildNodeKeyIsSet && parent.leftChildNodeKey == nodeKey, INVALID_ROTATION_NODES);

            // Replace left child of parent using info we saved.
            parent.leftChildNodeKey = newLeftChild;
            parent.leftChildNodeKeyIsSet = newLeftChildIsSet;

            // Set parent of parent node to be the original node.
            parent.parentNodeKey = nodeKey;
            parent.parentNodeKeyIsSet = true;
        };
    }

    // Performs a left rotation centered around a parent node (PN) and a child node (CN):
    //
    //     PN                          CN
    //    / \                         / \
    //   T1  CN       rotated       PN   T3
    //       / \    ---------->    / \
    //      T2  T3               T1  T2
    //
    // where T1, T2, T3, and T4 are subtrees (possibly empty).
    // If CN is not the left child of the parent, will throw an error.
    fun rotate_left<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, nodeKey: u128) {
        if (tree.rootNodeKey == parentNodeKey) {
            tree.rootNodeKey = nodeKey;
        };

        // First process the node mutations.
        let newRightChild = 0u128;
        let newRightChildIsSet = false;
        {
            // Save grandparent information for later.
            let parent = get_node(tree, parentNodeKey);
            let grandparentKey = parent.parentNodeKey;
            let grandparentKeyIsSet = parent.parentNodeKeyIsSet;
            // Modify grandparent to point to current node.
            if (grandparentKeyIsSet) {
                let grandparent = get_node_mut(tree, grandparentKey);
                if (grandparent.leftChildNodeKey == parentNodeKey) {
                    grandparent.leftChildNodeKey = nodeKey;
                } else {
                    grandparent.rightChildNodeKey = nodeKey;
                }
            };

            let node = get_node_mut(tree, nodeKey);

            // Validate node properties.
            assert!(node.parentNodeKeyIsSet && node.parentNodeKey == parentNodeKey, INVALID_ROTATION_NODES);

            // Disconnect from parent.
            node.parentNodeKeyIsSet = false;

            // If node has a left subtree, it becomes the right child of the parent.
            // We save this information for later.
            if (node.leftChildNodeKeyIsSet) {
                let leftChildNode = get_node_mut(tree, node.leftChildNodeKey);
                leftChildNode.parentNodeKey = parentNodeKey;
                leftChildNode.parentNodeKeyIsSet = true;
                newRightChild = leftChildNode.key;
                newRightChildIsSet = true;
            };

            // Re-borrow.
            let node = get_node_mut(tree, nodeKey);

            // Set parent of node to be its grandparent (using info we saved above).
            node.parentNodeKey = grandparentKey;
            node.parentNodeKeyIsSet = grandparentKeyIsSet;

            // Set left child of node to be the parent.
            node.leftChildNodeKey = parentNodeKey;
            node.leftChildNodeKeyIsSet = true;
        };

        // Now process the parent mutations.
        {
            let parent = get_node_mut(tree, parentNodeKey);

            // Validate parent properties.
            assert!(parent.rightChildNodeKeyIsSet && parent.rightChildNodeKey == nodeKey, INVALID_ROTATION_NODES);

            // Replace right child of parent using info we saved.
            parent.rightChildNodeKey = newRightChild;
            parent.rightChildNodeKeyIsSet = newRightChildIsSet;

            // Set parent of parent node to be the original node.
            parent.parentNodeKey = nodeKey;
            parent.parentNodeKeyIsSet = true;
        };
    }

    // Neither the parent's nor the child's children nodes will be effected; this is only swapping the
    // parents of both the parent and the child.
    fun swap_parents<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, childNodeKey: u128) {
        // 1. The child takes over the parent's spot; either as root (if parent is root), or as the grandprent's
        // left/right node, depending which direction the parent belonged.
        if (is_root_node(tree, parentNodeKey)) {
            // The parent is root! The child must be promoted to root!
            set_root_node(tree, childNodeKey);
        } else {
            let grandparentNodeKey = get_node(tree, parentNodeKey).parentNodeKey;
            let grandparentNode = get_node_mut(tree, grandparentNodeKey);
            if (grandparentNode.leftChildNodeKeyIsSet && grandparentNode.leftChildNodeKey == parentNodeKey) {
                grandparentNode.leftChildNodeKey = childNodeKey;
            } else {
                grandparentNode.rightChildNodeKey = childNodeKey;
            };
            let childNode = get_node_mut(tree, childNodeKey);
            childNode.parentNodeKey = grandparentNodeKey;
        };

        // 2. The child becomes the parent of the parent. Note that we're just updating the parent key here,
        // and that the child still needs to asign the parent either to its left or right child keys.
        let parentNode = get_node_mut(tree, parentNodeKey);
        parentNode.parentNodeKey = childNodeKey;
        parentNode.parentNodeKeyIsSet = true;
    }

    //
    // TEST SWAPS
    //

    #[test(signer = @0x345)]
    fun test_swap_with_successor_root_immediate(signer: signer) {
        // Node is root and successor immediate child.
        //    (10B)            15B
        //    /   \    ->    /   \
        //  5R    15R      5R    (10R)
        let tree = test_tree(vector<u128>[10, 5, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        swap_with_successor(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(R) 15 _ _: [0], 15(B) root 5 10: [0], 10(R) 15 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_root_not_immediate(signer: signer) {
        // Node is root and successor is not an immediate child.
        //      (14B)             15B
        //     /    \            /   \
        //    10B   16B   ->    10B   16B
        //   /      /          /      /
        //  5R    15R         5R    (14R)
        let tree = test_tree(vector<u128>[10, 5, 16, 14, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 16: [0], 15(R) 16 _ _: [0], 16(B) 14 15 _: [0]");
        swap_with_successor(&mut tree, 14);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 15 5 _: [0], 15(B) root 10 16: [0], 14(R) 16 _ _: [0], 16(B) 15 14 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_root_not_immediate_has_children(signer: signer) {
        // Node is root and successor is not an immediate child and has childrrn of its own.
        //      (14)               15
        //      /  \              /  \
        //    10   17    ->    10    17
        //   /    /  \         /    /  \
        //  5    15  18       5   (14) 18
        //         \                 \
        //          16                16
        let tree = test_tree(vector<u128>[10, 5, 15, 14, 18, 17, 16]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 17: [0], 15(B) 17 _ 16: [0], 16(R) 15 _ _: [0], 17(R) 14 15 18: [0], 18(B) 17 _ _: [0]");
        swap_with_successor(&mut tree, 14);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 15 5 _: [0], 15(B) root 10 17: [0], 14(B) 17 _ 16: [0], 16(R) 14 _ _: [0], 17(R) 15 14 18: [0], 18(B) 17 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_not_root_immediate(signer: signer) {
        // Node is not root and successor is an immediate child.
        //      15               15
        //     /  \             /  \
        //   (10)  17    ->   14   17
        //   / \              / \
        //  5  14            5  (10)
        let tree = test_tree(vector<u128>[10, 5, 15, 17, 14]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 15 5 14: [0], 14(R) 10 _ _: [0], 15(B) root 10 17: [0], 17(B) 15 _ _: [0]");
        swap_with_successor(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(R) 14 _ _: [0], 14(B) 15 5 10: [0], 10(R) 14 _ _: [0], 15(B) root 14 17: [0], 17(B) 15 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_not_root_not_immediate(signer: signer) {
        // Node is not root and successor is not an immediate child.
        //       14                14
        //      /  \              /  \
        //    10  (16)    ->    10   17
        //   /    /  \         /    /  \
        //  5    15  18       5    15  18
        //           /                 /
        //          17               (16)
        let tree = test_tree(vector<u128>[10, 5, 15, 14, 18, 16, 17]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 16: [0], 15(B) 16 _ _: [0], 16(R) 14 15 18: [0], 17(R) 18 _ _: [0], 18(B) 16 17 _: [0]");
        swap_with_successor(&mut tree, 16);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 17: [0], 15(B) 17 _ _: [0], 17(R) 14 15 18: [0], 16(R) 18 _ _: [0], 18(B) 17 16 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_not_immediate_has_children(signer: signer) {
        // Node is not root and successor not an immediate child and has children of is own.
        //       14                14
        //      /  \              /  \
        //    10  (16)    ->    10   17
        //   /    /  \         /    /  \
        //  5    15  17       5    15  (16)
        //             \                 \
        //              18                18
        let tree = test_tree(vector<u128>[10, 5, 15, 14, 17, 16, 18]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 16: [0], 15(B) 16 _ _: [0], 16(R) 14 15 17: [0], 17(B) 16 _ 18: [0], 18(R) 17 _ _: [0]");
        swap_with_successor(&mut tree, 16);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 14 5 _: [0], 14(B) root 10 17: [0], 15(B) 17 _ _: [0], 17(R) 14 15 16: [0], 16(B) 17 _ 18: [0], 18(R) 16 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_parents_with_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 8, 0);
        insert(&mut tree, 6, 0);
        insert(&mut tree, 7, 0);
        assert_red_black_tree(&tree);
        assert_inorder_tree(&tree, b"6(B) 7 _ _: [0], 7(B) root 6 8: [0], 8(B) 7 _ _: [0]");
        swap_parents(&mut tree, 7, 6);
        assert!(is_root_node(&tree, 6), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_parents(signer: signer) {
        let tree = test_tree(vector<u128>[8, 6, 7, 9, 5]);
        assert_inorder_tree(&tree, b"5(R) 6 _ _: [0], 6(B) 7 5 _: [0], 7(B) root 6 8: [0], 8(B) 7 _ 9: [0], 9(R) 8 _ _: [0]");
        swap_parents(&mut tree, 8, 9);
        swap_parents(&mut tree, 6, 5);
        let rootNode = root_node(&tree);
        assert!(rootNode.rightChildNodeKey == 9, 0);
        assert!(rootNode.leftChildNodeKey == 5, 0);
        assert!(is_root_node(&tree, 7), 0);
        move_to(&signer, tree)
    }

    //
    // TEST FIX DOUBLE RED
    //

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_1_1(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 31, 0);
        assert_inorder_tree(&tree, b"15(R) 21 _ _: [0], 21(B) root 15 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 10, 0);
        assert_inorder_tree(&tree, b"10(B) 15 _ _: [0], 15(B) root 10 21: [0], 21(B) 15 _ 31: [0], 31(R) 21 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_1_2(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 6, 0);
        assert_inorder_tree(&tree, b"5(B) 10 _ 6: [0], 6(R) 5 _ _: [0], 10(B) root 5 21: [0], 21(B) 10 _ 31: [0], 31(R) 21 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_1_3(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 10, 0);
        assert_inorder_tree(&tree, b"10(B) 15 _ _: [0], 15(B) root 10 21: [0], 21(B) 15 _ 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 5, 0);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 15 5 _: [0], 15(B) root 10 21: [0], 21(B) 15 _ 31: [0], 31(R) 21 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_2_1(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) root 10 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 41, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) 31 10 _: [0], 31(B) root 21 41: [0], 41(B) 31 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_2_2(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 41, 0);
        insert(&mut tree, 35, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) 31 10 _: [0], 31(B) root 21 41: [0], 35(R) 41 _ _: [0], 41(B) 31 35 _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_2_3(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 41, 0);
        insert(&mut tree, 51, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) 31 10 _: [0], 31(B) root 21 41: [0], 41(B) 31 _ 51: [0], 51(R) 41 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_deep(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 41, 0);
        insert(&mut tree, 35, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) 31 10 _: [0], 31(B) root 21 41: [0], 35(R) 41 _ _: [0], 41(B) 31 35 _: [0]");
        insert(&mut tree, 1, 0);
        assert_inorder_tree(&tree, b"1(B) 10 _ _: [0], 10(R) 31 1 21: [0], 21(B) 10 _ _: [0], 31(B) root 10 41: [0], 35(R) 41 _ _: [0], 41(B) 31 35 _: [0]");
        insert(&mut tree, 0, 0);
        assert_inorder_tree(&tree, b"0(R) 1 _ _: [0], 1(B) 10 0 _: [0], 10(R) 31 1 21: [0], 21(B) 10 _ _: [0], 31(B) root 10 41: [0], 35(R) 41 _ _: [0], 41(B) 31 35 _: [0]");
        insert(&mut tree, 15, 0);
        assert_inorder_tree(&tree, b"0(R) 1 _ _: [0], 1(B) 10 0 _: [0], 10(R) 31 1 21: [0], 15(R) 21 _ _: [0], 21(B) 10 15 _: [0], 31(B) root 10 41: [0], 35(R) 41 _ _: [0], 41(B) 31 35 _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    //
    // TEST ROTATIONS
    //

    #[test(signer = @0x345)]
    fun test_rotate_right_with_root(signer: signer) {
        let tree = test_tree(vector<u128>[10, 7, 15, 5, 8, 2, 6]);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(B) root 5 10: [0], 8(R) 10 _ _: [0], 10(B) 7 8 15: [0], 15(R) 10 _ _: [0]");
        rotate_right(&mut tree, 7, 5);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) root 2 7: [0], 6(R) 7 _ _: [0], 7(B) 5 6 10: [0], 8(R) 10 _ _: [0], 10(B) 7 8 15: [0], 15(R) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_right(signer: signer) {
        let tree = test_tree(vector<u128>[10, 7, 15, 5, 8, 2, 6]);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(B) root 5 10: [0], 8(R) 10 _ _: [0], 10(B) 7 8 15: [0], 15(R) 10 _ _: [0]");
        rotate_right(&mut tree, 10, 8);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(B) root 5 8: [0], 8(R) 7 _ 10: [0], 10(B) 8 _ 15: [0], 15(R) 10 _ _: [0]");
        assert!(is_root_node(&tree, 7), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_rotate_right_with_incorrect_nodes(signer: signer) {
        let tree = test_tree(vector<u128>[10, 4, 15, 14, 16]);
        rotate_right(&mut tree, 10, 16);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_left_with_root(signer: signer) {
        let tree = test_tree(vector<u128>[10, 4, 15, 14, 16]);
        assert_inorder_tree(&tree, b"4(R) 10 _ _: [0], 10(B) 14 4 _: [0], 14(B) root 10 15: [0], 15(B) 14 _ 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 14, 15);
        assert_inorder_tree(&tree, b"4(R) 10 _ _: [0], 10(B) 14 4 _: [0], 14(B) 15 10 _: [0], 15(B) root 14 16: [0], 16(R) 15 _ _: [0]");
        assert!(is_root_node(&tree, 15), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_left(signer: signer) {
        let tree = test_tree(vector<u128>[10, 4, 15, 14, 16]);
        assert_inorder_tree(&tree, b"4(R) 10 _ _: [0], 10(B) 14 4 _: [0], 14(B) root 10 15: [0], 15(B) 14 _ 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 15, 16);
        assert_inorder_tree(&tree, b"4(R) 10 _ _: [0], 10(B) 14 4 _: [0], 14(B) root 10 16: [0], 15(B) 16 _ _: [0], 16(R) 14 15 _: [0]");
        assert!(is_root_node(&tree, 14), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_rotate_left_with_incorrect_nodes(signer: signer) {
        let tree = test_tree(vector<u128>[10, 4, 15, 14, 16]);
        rotate_left(&mut tree, 10, 16);
        move_to(&signer, tree)
    }

    //
    // TEST INSERTION
    //

    #[test(signer = @0x345)]
    fun test_is_empty_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        assert!(is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 0, 0);
        assert!(!contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_with_empty_tree(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 1, 0);
        assert!(contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"10(B) root _ _: [100]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_at_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 1, 0);
        assert!(contains_key(&tree, 10), 0);
        assert_inorder_tree(&tree, b"10(B) root _ _: [10, 100]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 8, 1);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert_inorder_tree(&tree, b"8(R) 10 _ _: [10, 1], 10(B) root 8 _: [10]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_duplicate_on_first_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 10);
        insert(&mut tree, 12, 100);
        insert(&mut tree, 12, 1000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert_inorder_tree(&tree, b"10(B) root _ 12: [10], 12(R) 10 _ _: [100, 1000]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_left_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert!(*value_at(&tree, 8) == 10, 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert_inorder_tree(&tree, b"8(R) 10 _ _: [10], 10(B) root 8 _: [100]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_left_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 8, 10);
        insert(&mut tree, 6, 1);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert!(contains_key(&tree, 6), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 8) == 10, 0);
        assert!(*value_at(&tree, 6) == 1, 0);
        assert_inorder_tree(&tree, b"6(B) 8 _ _: [1], 8(B) root 6 10: [10], 10(B) 8 _ _: [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 2, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 12) == 1000, 0);
        assert_inorder_tree(&tree, b"10(B) root _ 12: [100], 12(R) 10 _ _: [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_two_right_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        insert(&mut tree, 14, 10000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert!(contains_key(&tree, 14), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 12) == 1000, 0);
        assert!(*value_at(&tree, 14) == 10000, 0);
        assert_inorder_tree(&tree, b"10(B) 12 _ _: [100], 12(B) root 10 14: [1000], 14(B) 12 _ _: [10000]");
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
        assert!(key_count<u128>(&tree) == 4, 0);
        assert_inorder_tree(&tree, b"6(B) 8 _ _: [5], 8(B) root 6 10: [10], 10(B) 8 _ 12: [100], 12(R) 10 _ _: [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_peek(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(key_count<u128>(&tree) == 1, 0);
        let (key, value) = peek<u128>(&tree);
        assert!(key == 10, 0);
        assert!(*value == 100, 0);
        move_to(&signer, tree)
    }

    //
    // DELETION TESTS.
    //

    #[test(signer = @0x345)]
    fun test_delete_root_leaf_node(signer: signer) {
        // It's just a leaf root node.
        let tree = test_tree(vector<u128>[10]);
        assert_inorder_tree(&tree, b"10(B) root _ _: [0]");
        assert!(key_count(&tree) == 1, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"");
        assert!(is_empty(&tree), 0);
        assert!(key_count(&tree) == 0, 0);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_red_left_successor(signer: signer) {
        // It's just a leaf root node.
        let tree = test_tree(vector<u128>[10, 5]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 _: [0]");
        assert!(key_count(&tree) == 2, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(B) root _ _: [0]");
        assert!(key_count(&tree) == 1, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_red_right_successor(signer: signer) {
        // It's just a leaf root node.
        let tree = test_tree(vector<u128>[10, 15]);
        assert_inorder_tree(&tree, b"10(B) root _ 15: [0], 15(R) 10 _ _: [0]");
        assert!(key_count(&tree) == 2, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"15(B) root _ _: [0]");
        assert!(key_count(&tree) == 1, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_two_red_successors(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        assert!(key_count(&tree) == 3, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(R) 15 _ _: [0], 15(B) root 5 _: [0]");
        assert!(key_count(&tree) == 2, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_black_node_with_two_children(signer: signer) {
        let tree = test_tree(vector<u128>[1, 2, 3, 4, 5, 6, 7]);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(B) 4 1 3: [0], 3(B) 2 _ _: [0], 4(B) root 2 6: [0], 5(B) 6 _ _: [0], 6(B) 4 5 7: [0], 7(B) 6 _ _: [0]");
        delete(&mut tree, 6);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(R) 4 1 3: [0], 3(B) 2 _ _: [0], 4(B) root 2 7: [0], 5(R) 7 _ _: [0], 7(B) 4 5 _: [0]");
        assert_red_black_tree(&tree);
        delete(&mut tree, 4);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(R) 5 1 3: [0], 3(B) 2 _ _: [0], 5(B) root 2 7: [0], 7(B) 5 _ _: [0]");
        delete(&mut tree, 1);
        assert_inorder_tree(&tree, b"2(B) 5 _ 3: [0], 3(R) 2 _ _: [0], 5(B) root 2 7: [0], 7(B) 5 _ _: [0]");
        delete(&mut tree, 7);
        assert_inorder_tree(&tree, b"2(B) 3 _ _: [0], 3(B) root 2 5: [0], 5(B) 3 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_red_leaf_nodes(signer: signer) {
        // It's just a leaf node.
        let tree = test_tree(vector<u128>[10, 5, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        delete(&mut tree, 5);
        assert_inorder_tree(&tree, b"10(B) root _ 15: [0], 15(R) 10 _ _: [0]");
        delete(&mut tree, 15);
        assert_inorder_tree(&tree, b"10(B) root _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_black_node_with_red_left_child_sucessor(signer: signer) {
        // The successor is red and is the left child of the node getting deleted.
        let tree = test_tree(vector<u128>[10, 5, 15, 3, 7, 2, 1]);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(R) 5 1 3: [0], 3(B) 2 _ _: [0], 5(B) root 2 10: [0], 7(R) 10 _ _: [0], 10(B) 5 7 15: [0], 15(R) 10 _ _: [0]");
        delete(&mut tree, 3);
        assert_inorder_tree(&tree, b"1(R) 2 _ _: [0], 2(B) 5 1 _: [0], 5(B) root 2 10: [0], 7(R) 10 _ _: [0], 10(B) 5 7 15: [0], 15(R) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_black_node_with_red_right_child_sucessor(signer: signer) {
        // The successor is red and is the left child of the node getting deleted.
        let tree = test_tree(vector<u128>[10, 5, 15, 7]);
        assert_inorder_tree(&tree, b"5(B) 7 _ _: [0], 7(B) root 5 10: [0], 10(B) 7 _ 15: [0], 15(R) 10 _ _: [0]");
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(B) 7 _ _: [0], 7(B) root 5 15: [0], 15(B) 7 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_a_i(signer: signer) {
        let tree = test_tree(vector<u128>[20, 15, 25, 10, 17]);
        delete(&mut tree, 25);
        assert_inorder_tree(&tree, b"10(B) 15 _ _: [0], 15(B) root 10 20: [0], 17(R) 20 _ _: [0], 20(B) 15 17 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_a_ii(signer: signer) {
        let tree = test_tree(vector<u128>[20, 15, 25, 17]);
        delete(&mut tree, 25);
        assert_inorder_tree(&tree, b"15(B) 17 _ _: [0], 17(B) root 15 20: [0], 20(B) 17 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_a_iii(signer: signer) {
        let tree = test_tree(vector<u128>[30, 20, 40, 35, 50]);
        delete(&mut tree, 20);
        assert_red_black_tree(&tree); // TODO: going to redo these with new case mapping.
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_a_iv(signer: signer) {
        let tree = test_tree(vector<u128>[30, 20, 40, 35]);
        delete(&mut tree, 20);
        assert_inorder_tree(&tree, b"30(B) 35 _ _: [0], 35(B) root 30 40: [0], 40(B) 35 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_b_black_parent(signer: signer) {
        let tree = test_tree(vector<u128>[20, 10, 25, 35]);
        delete(&mut tree, 35);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"20(B) root _ 25: [0], 25(R) 20 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_b_red_parent(signer: signer) {
        let tree = test_tree(vector<u128>[20, 10, 25, 30, 23, 35]);
        delete(&mut tree, 35);
        delete(&mut tree, 30);
        assert_inorder_tree(&tree, b"10(B) 20 _ _: [0], 20(B) root 10 25: [0], 23(R) 25 _ _: [0], 25(B) 20 23 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_c_i(signer: signer) {
        let tree = test_tree(vector<u128>[20, 10, 30, 1, 2, 3]);
        delete(&mut tree, 30);
        assert_red_black_tree(&tree); // TODO: going to redo these with new case mapping.
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_c_ii(signer: signer) {
        let tree = test_tree(vector<u128>[20, 10, 30, 45, 50, 55]);
        delete(&mut tree, 10);
        assert_red_black_tree(&tree); // TODO: going to redo these with new case mapping.
        move_to(&signer, tree)
    }

    //
    // FUZZ TESTING
    //

    #[test(signer = @0x345)]
    fun test_large_sorted_insertion(signer: signer) {
        let tree = new<u128>();
        let i = 0;
        while (i < 100) {
            insert(&mut tree, i, i);
            assert!(contains_key(&tree, i), 0);
            assert!(key_count<u128>(&tree) == i + 1, 0);
            assert_red_black_tree(&tree);
            i = i + 1;
        };
        while (i > 0) {
            i = i - 1;
            delete(&mut tree, i);
            assert!(!contains_key(&tree, i), 0);
            assert!(key_count<u128>(&tree) == i, 0);
            assert_red_black_tree(&tree);
        };
        assert!(is_empty(&tree), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_large_sorted_reverse_order(signer: signer) {
        let tree = new<u128>();
        let count = 100;
        let i = count;
        while (i > 0) {
            i = i - 1;
            insert(&mut tree, i, i);
            assert!(contains_key(&tree, i), 0);
            assert!(key_count<u128>(&tree) == count - i, 0);
            assert_red_black_tree(&tree);
        };
        while (i < count) {
            delete(&mut tree, i);
            assert!(!contains_key(&tree, i), 0);
            assert!(key_count<u128>(&tree) == count - i - 1, 0);
            assert_red_black_tree(&tree);
            i = i + 1;
        };
        assert!(is_empty(&tree), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_large_random_key_set_with_peek_deletion(signer: signer) {
        let tree = new<u128>();
        let i = 1;
        let count = 100;
        while (i < count) {
            let key = 340282366920938463463374607431768211455u128 % (i * i * i);
            insert(&mut tree, key, i);
            assert!(contains_key(&tree, key), 0);
            assert_red_black_tree(&tree);
            i = i + 1;
        };
        while (!is_empty(&tree)) {
            let (key, _) = peek(&tree);
            let keyCountBeforeDeletion = key_count<u128>(&tree);
            delete(&mut tree, key);
            assert!(keyCountBeforeDeletion == key_count<u128>(&tree) + 1, 0);
            assert_red_black_tree(&tree);
            i = i - 1;
        };
        assert!(is_empty(&tree), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_large_random_key_set_with_inorder_deletion(signer: signer) {
        let tree = new<u128>();
        let i = 1u64;
        let count = 100;
        let keys = &mut vector::empty<u128>();
        while (i < count) {
            let key = 34028236692093 % ((i * i * i * i) as u128);
            insert(&mut tree, key, 0);
            assert!(contains_key(&tree, key), 0);
            assert_red_black_tree(&tree);
            i = i + 1;
            // This avoids trying to remove duplicate keys and crashing.
            if (!vector::contains(keys, &key)) {
                vector::push_back(keys, key);
            };
        };
        i = 0;
        while (i < vector::length(keys)) {
            let key = *vector::borrow(keys, i);
            delete(&mut tree, key);
            assert_red_black_tree(&tree);
            i = i + 1;
        };
        assert!(is_empty(&tree), 0);
        move_to(&signer, tree)
    }

    //
    // TEST ONLY FUNCTIONS
    //

    #[test_only]
    fun s(bytes: vector<u8>): String {
        string::utf8(bytes)
    }

    #[test_only]
    fun test_tree(nodeKeys: vector<u128>) : Tree<u128> {
        let tree = new<u128>();
        let i = 0;
        while (i < vector::length(&nodeKeys)) {
            insert(&mut tree, *vector::borrow(&nodeKeys, i), 0);
            i = i + 1;
        };
        tree
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
        let currentNode = get_node(tree, currentNodeKey);
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
        let buffer = &mut s(b"");
        let len = vector::length(&inorderKeys);
        while (i < len) {
            let key = *vector::borrow(&inorderKeys, i);
            string::append(buffer, string_with_node(tree, key));
            i = i + 1;
            if (i < len) {
                string::append(buffer, s(b", "));
            }
        };
        *buffer
    }

    #[test_only]
    fun string_with_node(tree: &Tree<u128>, key: u128): String {
        let node = get_node(tree, key);
        let buffer = &mut s(b"");
        string::append(buffer, to_string_u128(key));
        string::append(buffer, s(if (is_red(tree, key)) b"(R)" else b"(B)"));
        if (node.parentNodeKeyIsSet) {
            string::append(buffer, s(b" "));
            string::append(buffer, to_string_u128(node.parentNodeKey));
        } else if (node.key == tree.rootNodeKey){
            string::append(buffer, s(b" root"));
        } else {
            string::append(buffer, s(b" ?"));
        };
        if (node.leftChildNodeKeyIsSet) {
            string::append(buffer, s(b" "));
            string::append(buffer, to_string_u128(node.leftChildNodeKey));
        } else {
            string::append(buffer, s(b" _"));
        };
        if (node.rightChildNodeKeyIsSet) {
            string::append(buffer, s(b" "));
            string::append(buffer, to_string_u128(node.rightChildNodeKey));
        } else {
            string::append(buffer, s(b" _"));
        };
        string::append(buffer, s(b": ["));
        string::append(buffer, to_string_vector(values_at(tree, key), b", "));
        string::append(buffer, s(b"]"));
        *buffer
    }

    #[test_only]
    fun parse_node(strRaw: vector<u8>, i: u64): (Node<u128>, u64) {
        // Parses the node from the string starting at position i. Also returns the starting position for the next
        // node. DOes not support parsing out node values.

        let str = &s(strRaw);
        let strLen = string::length(str);

        // Get node key.
        let buffer = &mut s(b"");
        let char = string::sub_string(str, i, i+1);
        while (char != s(b"(")) {
            string::append(buffer, char);
            i = i + 1;
            char = string::sub_string(str, i, i+1);
        };
        let key = u128_from_string(buffer);

        // Get node color.
        let isRed = string::sub_string(str, i+1, i+2) == s(b"R");

        i = i + 4;

        // Get parent.
        let buffer = &mut s(b"");
        let char = string::sub_string(str, i, i+1);
        while (char != s(b" ")) {
            string::append(buffer, char);
            i = i + 1;
            char = string::sub_string(str, i, i+1);
        };
        let parentNodeKeyIsSet = true;
        let parentNodeKey = 0u128;
        assert!(*buffer != s(b"?"), 0);
        if (*buffer == s(b"root")) {
            parentNodeKeyIsSet = false;
        } else {
            parentNodeKey = u128_from_string(buffer);
        };

        i = i + 1;

        // Get left child.
        let buffer = &mut s(b"");
        let char = string::sub_string(str, i, i+1);
        while (char != s(b" ")) {
            string::append(buffer, char);
            i = i + 1;
            char = string::sub_string(str, i, i+1);
        };
        let leftChildNodeKeyIsSet = true;
        let leftChildNodeKey = 0u128;
        if (*buffer == s(b"_")) {
            leftChildNodeKeyIsSet = false;
        } else {
            leftChildNodeKey = u128_from_string(buffer);
        };

        i = i + 1;

        // Get right child.
        let buffer = &mut s(b"");
        let char = string::sub_string(str, i, i+1);
        while (char != s(b":")) {
            string::append(buffer, char);
            i = i + 1;
            char = string::sub_string(str, i, i+1);
        };
        let rightChildNodeKeyIsSet = true;
        let rightChildNodeKey = 0u128;
        if (*buffer == s(b"_")) {
            rightChildNodeKeyIsSet = false;
        } else {
            rightChildNodeKey = u128_from_string(buffer);
        };

        let char = string::sub_string(str, i, i+1);
        while (i < strLen && char != s(b",")) {
            char = string::sub_string(str, i, i+1);
            i = i + 1;
        };

        if (i < strLen && string::sub_string(str, i, i+1) == s(b" ")) {
            // Account for extra space, so the new position value we return is exactly at the start
            // of the next node's info.
            i = i + 1;
        };

        let node = Node<u128>{
            key,
            values: vector::empty<u128>(),

            isRed,
            parentNodeKey,
            parentNodeKeyIsSet,
            leftChildNodeKey,
            leftChildNodeKeyIsSet,
            rightChildNodeKey,
            rightChildNodeKeyIsSet,
        };
        return (node, i)
    }

    #[test_only]
    fun parse_tree(strRaw: vector<u8>): Tree<u128> {
        // Note that this doesn't support parsing out node values.

        let tree = new<u128>();
        let str = s(strRaw);

        let i = 0;
        while (i < string::length(&str)) {
            let (node, newPos) = parse_node(strRaw, i);

            if (!node.parentNodeKeyIsSet) {
                tree.rootNodeKey = node.key;
            };
            table::add(&mut tree.nodes, node.key, node);
            tree.length = tree.length + 1;

            i = newPos;
        };
        tree
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
    const INVALID_ROOD_NODE_COLOR: u64 = 1;
    const TWO_ADJACENT_RED_NODES: u64 = 2;
    const INVALID_BLACK_NODE_DEPTH: u64 = 3;

    #[test_only]
    fun assert_red_black_tree(tree: &Tree<u128>) {
        // Condition 1: Every node has a color either red or black [no need to check].
        if (!is_empty(tree)) {
            // Condition 2. All node keys must point to other valid nodes.
            assert_correct_node_keys(tree, tree.rootNodeKey);
            // Condition 3. The root node must be black!
            assert!(!is_red(tree, tree.rootNodeKey), INVALID_ROOD_NODE_COLOR);
            // Condition 4: There are no two adjacent red nodes (A red node cannot have a red parent or a red child).
            assert_no_two_adjacent_red_nodes_inorder<u128>(tree, tree.rootNodeKey);
            // Condition 5: Every path from a node (including root) to any of its descendants leaf nodes has the same
            // number of black nodes.
            assert_black_node_depth_starting_node<u128>(tree, tree.rootNodeKey);
        };
        // Condition 6: All leaf nodes are black nodes [no need to check].
    }

    #[test_only]
    fun assert_correct_node_keys<V: store + drop>(tree: &Tree<V>, currentNodeKey: u128) {
        let currentNode = get_node(tree, currentNodeKey);
        if (currentNode.parentNodeKeyIsSet) {
            let parentNode = get_node(tree, currentNode.parentNodeKey);
            assert!(parentNode.key == currentNode.parentNodeKey, 0)
        };
        if (currentNode.leftChildNodeKeyIsSet) {
            let leftChildNode = get_node(tree, currentNode.leftChildNodeKey);
            assert!(leftChildNode.key == currentNode.leftChildNodeKey, 0);
            assert_correct_node_keys(tree, currentNode.leftChildNodeKey);
        };
        if (currentNode.rightChildNodeKeyIsSet) {
            let rightChildNode = get_node(tree, currentNode.rightChildNodeKey);
            assert!(rightChildNode.key == currentNode.rightChildNodeKey, 0);
            assert_correct_node_keys(tree, currentNode.rightChildNodeKey);
        };
    }

    #[test_only]
    fun assert_black_node_depth_starting_node<V: store + drop>(tree: &Tree<V>, currentNodeKey: u128) : u128 {
        let currentNodeCount = if (is_red(tree, currentNodeKey)) { 0 } else { 1 };
        if (has_left_child(tree, currentNodeKey) && has_right_child(tree, currentNodeKey)) {
            let leftChildDepth = assert_black_node_depth_starting_node(tree, left_child_key(tree, currentNodeKey));
            let rightChildDepth = assert_black_node_depth_starting_node(tree, right_child_key(tree, currentNodeKey));
            assert!(leftChildDepth == rightChildDepth, INVALID_BLACK_NODE_DEPTH);
            return currentNodeCount + leftChildDepth
        } else if (has_left_child(tree, currentNodeKey)) {
            let leftChildDepth = assert_black_node_depth_starting_node(tree, left_child_key(tree, currentNodeKey));
            return currentNodeCount + leftChildDepth
        } else if (has_right_child(tree, currentNodeKey)) {
            let rightChildDepth = assert_black_node_depth_starting_node(tree,right_child_key(tree, currentNodeKey));
            return currentNodeCount + rightChildDepth
        };
        return currentNodeCount
    }

    #[test_only]
    fun assert_no_two_adjacent_red_nodes_inorder<V: store + drop>(tree: &Tree<V>, currentNodeKey: u128) {
        let currentNode = get_node(tree, currentNodeKey);
        let isCurrentNodeRed = is_red(tree, currentNodeKey);
        if (currentNode.leftChildNodeKeyIsSet) {
            assert!(!isCurrentNodeRed || isCurrentNodeRed != is_red(tree, currentNode.leftChildNodeKey), TWO_ADJACENT_RED_NODES);
            assert_no_two_adjacent_red_nodes_inorder(tree, currentNode.leftChildNodeKey)
        };
        if (currentNode.rightChildNodeKeyIsSet) {
            assert!(!isCurrentNodeRed || isCurrentNodeRed != is_red(tree, currentNode.rightChildNodeKey), TWO_ADJACENT_RED_NODES);
            assert_no_two_adjacent_red_nodes_inorder(tree, currentNode.rightChildNodeKey)
        };
    }

    //
    // TEST, TEST ONLY FUNCTION
    // http://www.quickmeme.com/img/8c/8cf15c38cc3f6dc84a05c63daa0eab142e25e38a36969d86b01123a3502371c7.jpg
    //

    #[test(signer = @0x345)]
    fun test_parse_tree(signer: &signer) {
        let tree = parse_tree(b"0(B) 1 _ _: [], 1(B) root 0 3: [], 2(B) 3 _ _: [], 3(R) 1 2 4: [], 4(B) 3 _ _: []");
        assert_inorder_tree(&tree, b"0(B) 1 _ _: [], 1(B) root 0 3: [], 2(B) 3 _ _: [], 3(R) 1 2 4: [], 4(B) 3 _ _: []");
        move_to(signer, tree);
    }

    #[test]
    fun test_parse_node_multi_char_children() {
        let nodeStr = b"10(B) 1 100 30: [0]";
        let (node, len) = parse_node(nodeStr, 0);
        assert!(len == 19, 0);
        let expected = Node<u128>{
            key: 10,
            isRed: false,
            parentNodeKey: 1,
            parentNodeKeyIsSet: true,
            leftChildNodeKey: 100,
            leftChildNodeKeyIsSet: true,
            rightChildNodeKey: 30,
            rightChildNodeKeyIsSet: true,
            values: vector::empty(),
        };
        assert!(expected == node, 0);
    }

    #[test]
    fun test_parse_node_no_children() {
        let nodeStr = b"5(R) 21 _ _: [0]";
        let (node, len) = parse_node(nodeStr, 0);
        assert!(len == 16, 0);
        let expected = Node<u128>{
            key: 5,
            isRed: true,
            parentNodeKey: 21,
            parentNodeKeyIsSet: true,
            leftChildNodeKey: 0,
            leftChildNodeKeyIsSet: false,
            rightChildNodeKey: 0,
            rightChildNodeKeyIsSet: false,
            values: vector::empty(),
        };
        assert!(expected == node, 0);
    }

    #[test]
    fun test_parse_node_root() {
        let nodeStr = b"5(R) root 10 _: [0],";
        let (node, len) = parse_node(nodeStr, 0);
        assert!(len == 20, 0);
        let expected = Node<u128>{
            key: 5,
            isRed: true,
            parentNodeKey: 0,
            parentNodeKeyIsSet: false,
            leftChildNodeKey: 10,
            leftChildNodeKeyIsSet: true,
            rightChildNodeKey: 0,
            rightChildNodeKeyIsSet: false,
            values: vector::empty(),
        };
        assert!(expected == node, 0);
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_parent(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        get_node_mut<u128>(&mut tree, 15).parentNodeKeyIsSet = true;
        get_node_mut<u128>(&mut tree, 15).parentNodeKey = 100;
        assert_correct_node_keys(&tree, tree.rootNodeKey);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_left_child(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        get_node_mut<u128>(&mut tree, 15).leftChildNodeKeyIsSet = true;
        get_node_mut<u128>(&mut tree, 15).leftChildNodeKey = 100;
        assert_correct_node_keys(&tree, tree.rootNodeKey);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_right_child(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        get_node_mut<u128>(&mut tree, 15).rightChildNodeKeyIsSet = true;
        get_node_mut<u128>(&mut tree, 15).rightChildNodeKey = 100;
        assert_correct_node_keys(&tree, tree.rootNodeKey);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 1)]
    fun test_assert_red_black_tree_with_red_root_node(signer: signer) {
        let tree = test_tree(vector<u128>[10]);
        mark_red(&mut tree, 10);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_red_black_tree_with_two_adjacent_red_nodes(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35]);
        mark_red(&mut tree, 25);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_assert_red_black_tree_with_invalid_black_depth(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35, 40, 45]);
        mark_black(&mut tree, 45);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_assert_red_black_tree_with_invalid_black_depth_leaf_node(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35]);
        mark_black(&mut tree, 35);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }
}