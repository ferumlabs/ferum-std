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
    use ferum_std::test_utils::to_string_u128;
    #[test_only]
    use ferum_std::test_utils::to_string_vector;
    #[test_only]
    use std::string::{Self, String};

    ///
    /// ERRORS
    ///
    const TREE_IS_EMPTY: u64 = 0;
    const KEY_NOT_SET: u64 = 1;
    const NODE_NOT_FOUND: u64 = 2;
    const INVALID_ROTATION_NODES: u64 = 3;
    const INVALID_KEY_ACCESS: u64 = 4;
    const INVALID_SUCCESSOR_OPERATION: u64 = 5;
    const INVALID_DELETION_OPERATION: u64 = 6;
    const INVALID_OUTGOING_SWAP_EDGE_DIRECTION: u64 = 7;

    //
    // STRUCTS
    //

    struct Tree<V: store> has key {
        // Since the tree supports duplicate values, key count is different than value count.
        // Also, since the way we implement R/B doesn't have null leaf nodes, key count equals node count.
        keyCount: u128,
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
        Tree<V> { keyCount: 0, rootNodeKey: 0, nodes: table::new<u128, Node<V>>()}
    }

    ///
    /// PUBLIC ACCESSORS
    ///

    public fun is_empty<V: store + drop>(tree: &Tree<V>): bool {
        tree.keyCount == 0
    }

    public fun keyCount<V: store + drop>(tree: &Tree<V>): u128 {
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
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow_mut(&mut tree.nodes, key)
    }

    fun node_with_key<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, key), NODE_NOT_FOUND);
        table::borrow(&tree.nodes, key)
    }

    fun is_left_child<V: store + drop>(tree: &Tree<V>, childNodeKey: u128, parentNodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, childNodeKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentNodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, parentNodeKey)) {
            let parentNode = node_with_key(tree, parentNodeKey);
            return parentNode.leftChildNodeKey == childNodeKey
        };
        return false
    }

    fun has_left_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        node_with_key(tree, nodeKey).leftChildNodeKeyIsSet
    }

    fun left_child_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let leftChildNodeKey = node_with_key(tree, nodeKey).leftChildNodeKey;
        node_with_key_mut(tree, leftChildNodeKey)
    }

    fun is_right_child<V: store + drop>(tree: &Tree<V>, childNodeKey: u128, parentNodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, childNodeKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentNodeKey), NODE_NOT_FOUND);
        if (has_right_child(tree, parentNodeKey)) {
            let parentNode = node_with_key(tree, parentNodeKey);
            return parentNode.rightChildNodeKey == childNodeKey
        };
        return false
    }

    fun has_right_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        node_with_key(tree, nodeKey).rightChildNodeKeyIsSet
    }

    fun right_child_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        let rightChildNodeKey = node_with_key(tree, nodeKey).rightChildNodeKey;
        node_with_key_mut(tree, rightChildNodeKey)
    }

    fun right_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        node_with_key(tree, nodeKey).rightChildNodeKey
    }

    fun left_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        node_with_key(tree, nodeKey).leftChildNodeKey
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
        let node = node_with_key_mut(tree, nodeKey);
        node.parentNodeKeyIsSet = false;
        tree.rootNodeKey = nodeKey;
    }

    fun set_left_child<V: store + drop>(tree: &mut Tree<V>, parentKey: u128, childKey: u128) {
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(!has_left_child(tree, parentKey), INVALID_KEY_ACCESS);
        let parentNode = node_with_key_mut(tree, parentKey);
        parentNode.leftChildNodeKey = childKey;
        parentNode.leftChildNodeKeyIsSet = true;
        let childNode = node_with_key_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_left_child<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, nodeKey)) {
            let childNode = left_child_mut(tree, nodeKey);
            childNode.parentNodeKeyIsSet = false;
            let node = node_with_key_mut(tree, nodeKey);
            node.leftChildNodeKeyIsSet = false;
        };
    }

    fun set_right_child<V: store + drop>(tree: &mut Tree<V>, parentKey: u128, childKey: u128) {
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        let parentNode = node_with_key_mut(tree, parentKey);
        parentNode.rightChildNodeKey = childKey;
        parentNode.rightChildNodeKeyIsSet = true;
        let childNode = node_with_key_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_right_child<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_right_child(tree, nodeKey)) {
            let childNode = right_child_mut(tree, nodeKey);
            childNode.parentNodeKeyIsSet = false;
            let node = node_with_key_mut(tree, nodeKey);
            node.rightChildNodeKeyIsSet = false;
        };
    }

    fun has_parent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = node_with_key(tree, nodeKey);
        node.parentNodeKeyIsSet
    }

    fun set_parent<V: store + drop>(tree: &mut Tree<V>, childKey: u128, parentKey: u128) {
        assert!(table::contains(&tree.nodes, childKey), NODE_NOT_FOUND);
        assert!(table::contains(&tree.nodes, parentKey), NODE_NOT_FOUND);
        assert!(!has_parent(tree, childKey), INVALID_KEY_ACCESS);
        let childNode = node_with_key_mut(tree, childKey);
        childNode.parentNodeKey = parentKey;
        childNode.parentNodeKeyIsSet = true;
    }

    fun unset_parent<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        if (is_left_child(tree, nodeKey, parentNodeKey)) {
            unset_left_child(tree, parentNodeKey);
        } else {
            unset_right_child(tree, parentNodeKey);
        };
    }

    fun parent_node_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let node = node_with_key(tree, nodeKey);
        node.parentNodeKey
    }

    fun parent_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentKey = parent_node_key(tree, nodeKey);
        node_with_key_mut(tree, parentKey)
    }

    fun unset_all<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (has_parent(tree, nodeKey)) {
            unset_parent(tree, nodeKey);
        };
        if (has_right_child(tree, nodeKey)) {
            unset_right_child(tree, nodeKey);
        };
        if (has_left_child(tree, nodeKey)) {
            unset_left_child(tree, nodeKey);
        }
    }

    fun has_grandparent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = node_with_key(tree, nodeKey);
        if (node.parentNodeKeyIsSet) {
            let parent = node_with_key(tree, node.parentNodeKey);
            return parent.parentNodeKeyIsSet
        };
        return false
    }

    fun has_sibiling<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_parent(tree, nodeKey)) {
            let parentNodeKey = parent_node_key(tree, nodeKey);
            let parent = node_with_key(tree, parentNodeKey);
            return parent.leftChildNodeKeyIsSet && parent.rightChildNodeKeyIsSet
        };
        false
    }

    fun sibiling_node_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_sibiling(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        let parent = node_with_key(tree, parentNodeKey);
        if (parent.leftChildNodeKey == nodeKey) {
            parent.rightChildNodeKey
        } else {
            parent.leftChildNodeKey
        }
    }

    fun grandparent_node_key<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): u128 {
        assert!(has_grandparent(tree, nodeKey), INVALID_KEY_ACCESS);
        let node = node_with_key(tree, nodeKey);
        let parent = node_with_key(tree, node.parentNodeKey);
        parent.parentNodeKey
    }

    // Return the key of the node that would replace the node if it's deleted.
    // For example, if it's a leaf node, there are not replacement nodes, so we return (false, 0).
    fun successor_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): (bool, u128) { // (hasSuccessor, successorKey)
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_left_child(tree, nodeKey) && has_right_child(tree, nodeKey)) {
            let nodeRightChildKey = right_child_key(tree, nodeKey);
            (true, min_node_key_starting_at_node(tree, nodeRightChildKey))
        } else if (has_left_child(tree, nodeKey)) {
            (true, left_child_key(tree, nodeKey))
        } else if (has_right_child(tree, nodeKey)) {
            (true, right_child_key(tree, nodeKey))
        } else {
            (false, 0)
        }
    }

    ///
    /// MIN/MAX ACESSORS
    ///

    fun min_node_key_starting_at_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        while(has_left_child(tree, nodeKey)) {
            nodeKey = left_child_key(tree, nodeKey);
        };
        nodeKey
    }

    ///
    /// COLOR ACCESSORS
    ///

    fun is_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        node_with_key(tree, nodeKey).isRed
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
        let parentNode = node_with_key(tree, parentNodeKey);
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
        node_with_key_mut(tree, nodeKey).isRed = true;
    }

    fun mark_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        node_with_key_mut(tree, nodeKey).isRed = false;
    }

    fun mark_color<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128, isRed: bool) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        node_with_key_mut(tree, nodeKey).isRed = isRed;
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
        let sibilingNode = node_with_key_mut(tree, sibilingNodeKey);
        sibilingNode.isRed = true
    }

    fun mark_parent_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentNodeKey = parent_node_key(tree, nodeKey);
        let parentNode = node_with_key_mut(tree, parentNodeKey);
        parentNode.isRed = false;
    }

    fun mark_grandparent_red<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        assert!(has_grandparent(tree, nodeKey), INVALID_KEY_ACCESS);
        let grandparentNodeKey = grandparent_node_key(tree, nodeKey);
        let grandparentNode = node_with_key_mut(tree, grandparentNodeKey);
        grandparentNode.isRed = true;
    }

    ///
    /// INSERTION
    ///

    public fun insert<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V) {
        if (is_empty(tree)) {
            // If the tree is empty, instantiate a new root!
            let rootNode = leaf_node<V>(key, value);
            // Root node is always black!
            rootNode.isRed = false;
            tree.keyCount = tree.keyCount + 1;
            tree.rootNodeKey = key;
            table::add(&mut tree.nodes, key, rootNode);
        } else {
            // Otherwise, recursively insert starting at the root node.
            let rootNodeKey = tree.rootNodeKey;
            insert_starting_at_node(tree, key, value, rootNodeKey);
        };
        // In case any red/black invariants were broken, fix it up!
        fix_double_red(tree, key)
    }

    fun insert_starting_at_node<V: store + drop>(tree: &mut Tree<V>, key: u128, value: V, nodeKey: u128) {
        let node = node_with_key_mut(tree, nodeKey);
        if (key == node.key) {
            // Because this is a duplicate key, we must not increase the tree's key count!
            vector::push_back(&mut node.values, value);
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
                tree.keyCount = tree.keyCount + 1;
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
                tree.keyCount = tree.keyCount + 1;
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

    ///
    /// DELETIONS
    ///

    // The code in GeeksForGeeks has many bugs, use the discussion board to see them.
    // https://www.geeksforgeeks.org/red-black-tree-set-3-delete-2/
    public fun delete<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (has_left_child(tree, nodeKey) && has_right_child(tree, nodeKey)) { // Has 2 children!
            // Scenario 1: We have two children. What we want to do is find a succesor which
            // by definintion will have at most one child on right, then swap it out with the current node.
            // After the swap, the deletion should be handled by one of the scenarios below.
            swap_with_successor(tree, nodeKey);
            delete(tree, nodeKey);
        } else if (has_left_child(tree, nodeKey) || has_right_child(tree, nodeKey)) { // Has at leat 1 child!
            let (hasSuccssor, successorKey) = successor_key(tree, nodeKey);
            assert!(hasSuccssor, INVALID_SUCCESSOR_OPERATION);
            // Scenario 2: Handle a deletion of the root node, with only a single child.
            // The root node is always black, so removing it subtracts -1 black from depth.
            // We make it's successsor black, and even out the number.
            if (is_root_node(tree, nodeKey)) {
                let successorNode = node_with_key_mut(tree, successorKey);
                successorNode.parentNodeKeyIsSet = false;
                successorNode.isRed = false;
                tree.rootNodeKey = successorNode.key;
                drop_node(tree, nodeKey);
            } else { // is leaf node!
                // Scenario 3: We have one successor, and we're not the rood node. If either
                // the deleted node or the replacement node is red, then we color the
                // successor as black (red + black = black i.e. still 1 black). If both
                // are black, then we start fixing a double black at the successor.
                swap_parents(tree, nodeKey, successorKey);
                if (is_red(tree, nodeKey) || is_red(tree, successorKey)) {
                    let successorNode = node_with_key_mut(tree, successorKey);
                    successorNode.isRed = false;
                } else {
                    fix_double_black(tree, successorKey);
                };
                drop_node(tree, nodeKey);
            }
        } else { // Leaf node!
            // Scenario 4: Handle leaf node case. If it's the root, just delete the node. Otherwise, if
            // the deleted node is black, there must be an imbalance; fix the double black!
            if (is_black(tree, nodeKey)) {
                // The deletion of a black leaf causes an imbalance! Fix the double black!
                fix_double_black(tree, nodeKey);
            };
            drop_node(tree, nodeKey);
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
                if (is_left_child(tree, sibilingNodeKey, parentNodeKey)) {
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
                    if (is_left_child(tree, sibilingNodeKey, parentNodeKey)) { // Sibiling is the left child!
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

    const OUTGOING_SWAP_EDGE_DIRECTION_LEFT_CHILD: u8 = 1;
    const OUTGOING_SWAP_EDGE_DIRECTION_RIGHT_CHILD: u8  = 2;
    const OUTGOING_SWAP_EDGE_DIRECTION_PARENT_LEFT: u8  = 3;
    const OUTGOING_SWAP_EDGE_DIRECTION_PARENT_RIGHT: u8  = 4;

    struct OutgoingSwapEdge has copy, drop {
        target: u128,
        direction: u8,
    }

    fun outgoing_edges<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): vector<OutgoingSwapEdge> {
        let outgoingEdges = &mut vector::empty<OutgoingSwapEdge>();
        if (has_right_child(tree, nodeKey)) {
            let rightChildNodeKey = right_child_key(tree, nodeKey);
            vector::push_back(outgoingEdges, OutgoingSwapEdge { target: rightChildNodeKey, direction: OUTGOING_SWAP_EDGE_DIRECTION_RIGHT_CHILD });
        };
        if (has_left_child(tree, nodeKey)) {
            let leftChildNodeKey = left_child_key(tree, nodeKey);
            vector::push_back(outgoingEdges, OutgoingSwapEdge { target: leftChildNodeKey, direction: OUTGOING_SWAP_EDGE_DIRECTION_LEFT_CHILD });
        };
        if (has_parent(tree, nodeKey)) {
            let parentNodeKey = parent_node_key(tree, nodeKey);
            if (is_left_child(tree, nodeKey, parentNodeKey)) {
                vector::push_back(outgoingEdges, OutgoingSwapEdge { target: parentNodeKey, direction: OUTGOING_SWAP_EDGE_DIRECTION_PARENT_LEFT });
            } else {
                vector::push_back(outgoingEdges, OutgoingSwapEdge { target: parentNodeKey, direction: OUTGOING_SWAP_EDGE_DIRECTION_PARENT_RIGHT });
            };
        };
        *outgoingEdges
    }

    fun apply_outgoing_edges<V: store + drop>(tree: &mut Tree<V>, outgoingEdges: &vector<OutgoingSwapEdge>, nodeKey: u128, cycleBreakingNodeKey: u128) {
        let i = 0;
        while (i < vector::length(outgoingEdges)) {
            let edge = vector::borrow(outgoingEdges, i);
            let target =  if (edge.target == nodeKey) cycleBreakingNodeKey else edge.target;
            if (edge.direction == OUTGOING_SWAP_EDGE_DIRECTION_LEFT_CHILD) {
                set_left_child(tree, nodeKey, target);
            } else if (edge.direction == OUTGOING_SWAP_EDGE_DIRECTION_RIGHT_CHILD) {
                set_right_child(tree, nodeKey, target);
            } else if (edge.direction == OUTGOING_SWAP_EDGE_DIRECTION_PARENT_LEFT) {
                set_left_child(tree, target, nodeKey);
            } else if (edge.direction == OUTGOING_SWAP_EDGE_DIRECTION_PARENT_RIGHT) {
                set_right_child(tree, target, nodeKey);
            } else {
                assert!(false, INVALID_OUTGOING_SWAP_EDGE_DIRECTION);
            };
            i = i + 1;
        }
    }

    // Let's start with some interesting conditions for our successor swap:
    //
    //  Requirement 1. Node (N) must have two children!
    //  Requirement 2. Successor (S) must not have a left child (otherwise, left child should have been successor).
    //  Requirement 3. Node (N) may optionally be the root (R) i.e. N = R.
    //  Requirement 4. Successor (S) may optionally be node's (N) right child (N.rightChild) i.e. S = N.rightChild.
    //  Requirement 5. Successor (S) may optionally have a right child (S.rightChild).
    //  Requirement 6. After the swap, the coloring of the tree must not change i.e. swap(N.color, S.color)!
    //
    // As you can see, there are a lot of edges involved; doing the swap manually, one edge at a time is both error
    // prone and complex. Instead, here we opt to copy all the edges into a temprorary edge struct, then clearing all
    // the existing edges on the node, then applying the swapped version of the edges. The successor swap only happens
    // at most once for a node deletion, so this shouldn't affect performance.
    //
    //
    fun swap_with_successor<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        let (hasSuccesor, successorKey) = successor_key(tree, nodeKey);
        assert!(has_left_child(tree, nodeKey) && has_right_child(tree, nodeKey), INVALID_SUCCESSOR_OPERATION);
        assert!(hasSuccesor, INVALID_SUCCESSOR_OPERATION);
        let nodeOutgoingEdges = outgoing_edges(tree, nodeKey);
        let successorOutgoingEdges = outgoing_edges(tree, successorKey);
        unset_all(tree, nodeKey);
        unset_all(tree, successorKey);
        apply_outgoing_edges(tree, &successorOutgoingEdges, nodeKey, successorKey);
        apply_outgoing_edges(tree, &nodeOutgoingEdges, successorKey, nodeKey);
        if (tree.rootNodeKey == nodeKey) {
            tree.rootNodeKey = successorKey;
        };
        let isNodeRed = is_red(tree, nodeKey);
        let isSuccessorRed = is_red(tree, successorKey);
        mark_color(tree, nodeKey, isSuccessorRed);
        mark_color(tree, successorKey, isNodeRed);
    }

    // Mostly, following the guidelines here: https://www.programiz.com/dsa/insertion-in-a-red-black-tree.
    // It's much easier to follow the code from the above link, than the diagrams & annotations.
    // Also note that in the tutorial's code, the diagram's and the code have the top level if statement flipped.
    // If you're using, good visualization here: https://www.cs.usfca.edu/~galles/visualization/RedBlack.html.
    fun fix_double_red<V: store + drop>(tree: &mut Tree<V>, currentNodeKey: u128) {
        // 1. Continue while the parent of the current node is red! Keep in mind that root is always black, so
        // this condition only applies to 3rd layers and below.
        while (has_parent(tree, currentNodeKey) && is_parent_red(tree, currentNodeKey)) {
            assert!(has_grandparent(tree, currentNodeKey), 0);
            let parentNodeKey = parent_node_key(tree, currentNodeKey);
            let grandparentNodeKey = parent_node_key(tree, parentNodeKey);
            // 2. Split based on if the current parent is on the left or on the right side of the grandparent.
            if (is_left_child(tree, parentNodeKey, grandparentNodeKey)) {
                // 2. Case-I: If the color of the right child of grandaprent of current node is RED, set the color of
                // both the children of grandparent as BLACK and the color of grandparent as RED.
                if (has_right_child(tree, grandparentNodeKey) && is_right_child_red(tree, grandparentNodeKey) ) {
                    mark_children_black(tree, grandparentNodeKey);
                    mark_red(tree, grandparentNodeKey);
                    currentNodeKey = grandparentNodeKey;
                } else {
                    // 2. Case-II: Else if current node is the right child of the parent node then, left rotate the
                    // current node and parent node, then assign parent to be the new current node.
                    if (is_right_child(tree, currentNodeKey, parentNodeKey)) {
                        rotate_left(tree, parentNodeKey, currentNodeKey);
                        currentNodeKey = parentNodeKey;
                    };
                    // 2. Case-III: Set the color of the new parent of curent node as black, and grandparent as red;
                    // then right rotate the grandparent.
                    mark_parent_black(tree, currentNodeKey);
                    mark_grandparent_red(tree, currentNodeKey);
                    let parentNodeKey = parent_node_key(tree, currentNodeKey);
                    let grandparentNodeKey = grandparent_node_key(tree, currentNodeKey);
                    rotate_right(tree, grandparentNodeKey, parentNodeKey);
                }
            } else {
                // 3. The code below is the mirror version of the one above. For example, we check if the left uncle
                // is black instead of the right uncle unlike we did above. Similarly, we still need to handle 3 cases!
                // 3. Case-I: If the left uncle is black, then mark both parents as black, and grandparent as red.
                if (has_left_child(tree, grandparentNodeKey) && is_left_child_red(tree, grandparentNodeKey) ) {
                    mark_children_black(tree, grandparentNodeKey);
                    mark_red(tree, grandparentNodeKey);
                    currentNodeKey = grandparentNodeKey;
                } else {
                    // 3. Case-II: Else if current node is the left child of the parent node, then right rotate the
                    // current node and parent node, then assign parent to be the new current node.
                    if (is_left_child(tree, currentNodeKey, parentNodeKey)) {
                        rotate_right(tree, parentNodeKey, currentNodeKey);
                        currentNodeKey = parentNodeKey;
                    };
                    // 3. Case-III: Set the color of the new parent of curent node as black, and grandparent as red;
                    // then left rotate the grandparent.
                    mark_parent_black(tree, currentNodeKey);
                    mark_grandparent_red(tree, currentNodeKey);
                    let parentNodeKey = parent_node_key(tree, currentNodeKey);
                    let grandparentNodeKey = grandparent_node_key(tree, currentNodeKey);
                    rotate_left(tree, grandparentNodeKey, parentNodeKey);
                }
            }
        };

        // 4. Lastly, set the root of the tree as BLACK.
        let rootNodeKey = tree.rootNodeKey;
        mark_black(tree, rootNodeKey);
    }

    ///
    /// ROTATIONS
    ///

    fun rotate_right<V: store + drop>(tree: &mut Tree<V>, parentNodeKey: u128, childNodeKey: u128) {
        // 0. Check parent/child preconditions!
        {
            let parentNode = node_with_key(tree, parentNodeKey);
            let childNode = node_with_key(tree, childNodeKey);
            assert!(parentNode.leftChildNodeKey == childNodeKey, INVALID_ROTATION_NODES);
            assert!(childNode.parentNodeKey == parentNodeKey, INVALID_ROTATION_NODES);
        };

        // 1. If child has a right subtree, assign parent as the new parent of the right subtree of the child.
        if (has_right_child(tree, childNodeKey)) {
            let rightGrandchildNodeKey = node_with_key(tree, childNodeKey).rightChildNodeKey;
            let rightGrandchildNode = node_with_key_mut(tree, rightGrandchildNodeKey);
            // a. Fix the link upwards; the right substree points to the grandparent.
            rightGrandchildNode.parentNodeKey = parentNodeKey;
            // b. Parent node's left child now points to child's right substree.
            let parent = node_with_key_mut(tree, parentNodeKey);
            parent.leftChildNodeKey = rightGrandchildNodeKey;
            parent.leftChildNodeKeyIsSet = true;
        } else {
            // If the child node doesn't have a left subtree, we must disconnect the parent from the child.
            let parent = node_with_key_mut(tree, parentNodeKey);
            parent.leftChildNodeKeyIsSet = false;
        };

        // 2. Swap the parents; the parent's parent is now the child, and the child's parent is the parent's old parent.
        swap_parents(tree, parentNodeKey, childNodeKey);

        // 3. Make the parent the new child of the child (as the right node).
        let childNode = node_with_key_mut(tree, childNodeKey);
        childNode.rightChildNodeKey = parentNodeKey;
        childNode.rightChildNodeKeyIsSet = true;
    }

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

        // 2. Swap the parents; the parent's parent is now the child, and the child's parent is the parent's old parent.
        swap_parents(tree, parentNodeKey, childNodeKey);

        // 3. Make the parent the new child of the child (as the left node).
        let childNode = node_with_key_mut(tree, childNodeKey);
        childNode.leftChildNodeKey = parentNodeKey;
        childNode.leftChildNodeKeyIsSet = true;
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

        // 2. The child becomes the parent of the parent. Note that we're just updating the parent key here,
        // and that the child still needs to asign the parent either to its left or right child keys.
        let parentNode = node_with_key_mut(tree, parentNodeKey);
        parentNode.parentNodeKey = childNodeKey;
        parentNode.parentNodeKeyIsSet = true;
    }

    //
    // TEST SWAPS
    //

    #[test(signer = @0x345)]
    fun test_swap_with_successor_test_root_immediate(signer: signer) {
        // Node is root and successor is right child as a leaf node.
        //     10B            15B
        //    /   \    ->    /   \
        //  5R    15R      5R    10R
        let tree = test_tree(vector<u128>[10, 5, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        swap_with_successor(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(R) 15 _ _: [0], 15(B) root 5 10: [0], 10(R) 15 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_test_root_not_immediate(signer: signer) {
        // Node is root and successor is not its right child.
        //    (10B)              14B
        //   /    \             /  \
        //  5B    15B   ->    5B   15B
        //       /                /
        //     14R             (10R)
        let tree = test_tree(vector<u128>[10, 5, 15, 14]);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 _: [0]");
        swap_with_successor(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(B) 14 _ _: [0], 14(B) root 5 15: [0], 10(R) 15 _ _: [0], 15(B) 14 10 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_test_root_not_immediate_with_right_child(signer: signer) {
        // Node is not root and successor is right leaf child.
        //   (10B)              13B
        //   /   \             /  \
        //  5B   15R    ->    5B  15R
        //      /  \             /  \
        //    13B  25B       (10B)  25B
        //      \               \
        //      14R              14R
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 13, 14]);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 15: [0], 13(B) 15 _ 14: [0], 14(R) 13 _ _: [0], 15(R) 10 13 25: [0], 25(B) 15 _ _: [0]");
        swap_with_successor(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(B) 13 _ _: [0], 13(B) root 5 15: [0], 10(B) 15 _ 14: [0], 14(R) 10 _ _: [0], 15(R) 13 10 25: [0], 25(B) 15 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_test_not_root_immediate(signer: signer) {
        // Node is not root and successor is right leaf child.
        //    10               10
        //   /  \             /  \
        //  5  (15)    ->     5   17
        //     /  \             /   \
        //    14  17          14    (15)
        let tree = test_tree(vector<u128>[10, 5, 15, 17, 14]);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 17: [0], 17(R) 15 _ _: [0]");
        swap_with_successor(&mut tree, 15);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 17: [0], 14(R) 17 _ _: [0], 17(B) 10 14 15: [0], 15(R) 17 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_with_successor_test_not_root_not_immediate(signer: signer) {
        // Node is not root and successor is right leaf child.
        //    10               10
        //   /  \             /  \
        //  5  (15)    ->    5    16
        //     /  \             /   \
        //    14  17          14    17
        //       /                 /
        //     16                (15)
        let tree = test_tree(vector<u128>[10, 5, 15, 14, 17, 16]);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 15: [0], 14(B) 15 _ _: [0], 15(R) 10 14 17: [0], 16(R) 17 _ _: [0], 17(B) 15 16 _: [0]");
        swap_with_successor(&mut tree, 15);
        assert_inorder_tree(&tree, b"5(B) 10 _ _: [0], 10(B) root 5 16: [0], 14(B) 16 _ _: [0], 16(R) 10 14 17: [0], 15(R) 17 _ _: [0], 17(B) 16 15 _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_swap_parents_with_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 8, 0);
        insert(&mut tree, 6, 0);
        insert(&mut tree, 7, 0);
        assert_inorder_tree(&tree, b"6(R) 7 _ _: [0], 7(B) root 6 8: [0], 8(R) 7 _ _: [0]");
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
        assert_inorder_tree(&tree, b"10(R) 15 _ _: [0], 15(B) 21 10 _: [0], 21(B) root 15 31: [0], 31(B) 21 _ _: [0]");
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
        assert_inorder_tree(&tree, b"5(R) 6 _ _: [0], 6(B) 21 5 10: [0], 10(R) 6 _ _: [0], 21(B) root 6 31: [0], 31(B) 21 _ _: [0]");
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
        assert_inorder_tree(&tree, b"10(R) 15 _ _: [0], 15(B) 21 10 _: [0], 21(B) root 15 31: [0], 31(B) 21 _ _: [0]");
        insert(&mut tree, 5, 0);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 21 5 15: [0], 15(R) 10 _ _: [0], 21(B) root 10 31: [0], 31(B) 21 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_double_red_insertion_case_2_1t(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) root 10 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 41, 0);
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 31: [0], 31(B) 21 _ 41: [0], 41(R) 31 _ _: [0]");
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
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
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
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 41: [0], 31(R) 41 _ _: [0], 41(B) 21 31 51: [0], 51(R) 41 _ _: [0]");
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
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
        insert(&mut tree, 1, 0);
        assert_inorder_tree(&tree, b"1(R) 10 _ _: [0], 10(B) 21 1 _: [0], 21(B) root 10 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
        insert(&mut tree, 0, 0);
        assert_inorder_tree(&tree, b"0(R) 1 _ _: [0], 1(B) 21 0 10: [0], 10(R) 1 _ _: [0], 21(B) root 1 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
        insert(&mut tree, 15, 0);
        assert_inorder_tree(&tree, b"0(B) 1 _ _: [0], 1(R) 21 0 10: [0], 10(B) 1 _ 15: [0], 15(R) 10 _ _: [0], 21(B) root 1 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    //
    // TEST ROTATIONS
    //

    #[test(signer = @0x345)]
    fun test_rotate_right_with_root(signer: signer) {
        let tree = test_tree(vector<u128>[10, 7, 15, 5, 8, 2, 6]);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) 10 5 8: [0], 8(B) 7 _ _: [0], 10(B) root 7 15: [0], 15(B) 10 _ _: [0]");
        rotate_right(&mut tree, 10, 7);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) root 5 10: [0], 8(B) 10 _ _: [0], 10(B) 7 8 15: [0], 15(B) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_right(signer: signer) {
        let tree = test_tree(vector<u128>[10, 7, 15, 5, 8, 2, 6]);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) 10 5 8: [0], 8(B) 7 _ _: [0], 10(B) root 7 15: [0], 15(B) 10 _ _: [0]");
        rotate_right(&mut tree, 7, 5);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 10 2 7: [0], 6(R) 7 _ _: [0], 7(R) 5 6 8: [0], 8(B) 7 _ _: [0], 10(B) root 5 15: [0], 15(B) 10 _ _: [0]");
        assert!(is_root_node(&tree, 10), 0);
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
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 10, 15);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) 15 4 14: [0], 14(R) 10 _ _: [0], 15(B) root 10 16: [0], 16(R) 15 _ _: [0]");
        assert!(is_root_node(&tree, 15), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_left(signer: signer) {
        let tree = test_tree(vector<u128>[10, 4, 15, 14, 16]);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 15, 16);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 16: [0], 14(R) 15 _ _: [0], 15(B) 16 14 _: [0], 16(R) 10 15 _: [0]");
        assert!(is_root_node(&tree, 10), 0);
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
        assert!(keyCount<u128>(&tree) == 0, 0);
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
        assert!(keyCount<u128>(&tree) == 1, 0);
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
        assert!(keyCount<u128>(&tree) == 1, 0);
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
        assert!(keyCount<u128>(&tree) == 2, 0);
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
        assert!(keyCount<u128>(&tree) == 2, 0);
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
        assert!(keyCount<u128>(&tree) == 2, 0);
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
        assert!(keyCount<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 8), 0);
        assert!(contains_key(&tree, 6), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 8) == 10, 0);
        assert!(*value_at(&tree, 6) == 1, 0);
        assert_inorder_tree(&tree, b"6(R) 8 _ _: [1], 8(B) root 6 10: [10], 10(R) 8 _ _: [100]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_insert_right_child(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        insert(&mut tree, 12, 1000);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(keyCount<u128>(&tree) == 2, 0);
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
        assert!(keyCount<u128>(&tree) == 3, 0);
        assert!(contains_key(&tree, 10), 0);
        assert!(contains_key(&tree, 12), 0);
        assert!(contains_key(&tree, 14), 0);
        assert!(*value_at(&tree, 10) == 100, 0);
        assert!(*value_at(&tree, 12) == 1000, 0);
        assert!(*value_at(&tree, 14) == 10000, 0);
        assert_inorder_tree(&tree, b"10(R) 12 _ _: [100], 12(B) root 10 14: [1000], 14(R) 12 _ _: [10000]");
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
        assert!(keyCount<u128>(&tree) == 4, 0);
        assert_inorder_tree(&tree, b"6(R) 8 _ _: [5], 8(B) 10 6 _: [10], 10(B) root 8 12: [100], 12(B) 10 _ _: [1000]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_peek(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 100);
        assert!(!is_empty<u128>(&tree), 0);
        assert!(keyCount<u128>(&tree) == 1, 0);
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
        assert!(keyCount(&tree) == 1, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"");
        assert!(is_empty(&tree), 0);
        assert!(keyCount(&tree) == 0, 0);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_red_left_successor(signer: signer) {
        // It's just a leaf root node.
        let tree = test_tree(vector<u128>[10, 5]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 _: [0]");
        assert!(keyCount(&tree) == 2, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(B) root _ _: [0]");
        assert!(keyCount(&tree) == 1, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_red_right_successor(signer: signer) {
        // It's just a leaf root node.
        let tree = test_tree(vector<u128>[10, 15]);
        assert_inorder_tree(&tree, b"10(B) root _ 15: [0], 15(R) 10 _ _: [0]");
        assert!(keyCount(&tree) == 2, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"15(B) root _ _: [0]");
        assert!(keyCount(&tree) == 1, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_root_node_with_two_red_successors(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15]);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        assert!(keyCount(&tree) == 3, 0);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"5(R) 15 _ _: [0], 15(B) root 5 _: [0]");
        assert!(keyCount(&tree) == 2, 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_black_node_with_two_children(signer: signer) {
        let tree = test_tree(vector<u128>[1, 2, 3, 4, 5, 6, 7]);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(B) root 1 4: [0], 3(B) 4 _ _: [0], 4(R) 2 3 6: [0], 5(R) 6 _ _: [0], 6(B) 4 5 7: [0], 7(R) 6 _ _: [0]");
        delete(&mut tree, 6);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(B) root 1 4: [0], 3(B) 4 _ _: [0], 4(R) 2 3 7: [0], 5(R) 7 _ _: [0], 7(B) 4 5 _: [0]");
        delete(&mut tree, 4);
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(B) root 1 5: [0], 3(B) 5 _ _: [0], 5(R) 2 3 7: [0], 7(B) 5 _ _: [0]");
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
        let tree = test_tree(vector<u128>[10, 5, 15, 3, 7, 1]);
        assert_inorder_tree(&tree, b"1(R) 3 _ _: [0], 3(B) 5 1 _: [0], 5(R) 10 3 7: [0], 7(B) 5 _ _: [0], 10(B) root 5 15: [0], 15(B) 10 _ _: [0]");
        delete(&mut tree, 3);
        assert_inorder_tree(&tree, b"1(B) 5 _ _: [0], 5(R) 10 1 7: [0], 7(B) 5 _ _: [0], 10(B) root 5 15: [0], 15(B) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_black_node_with_red_right_child_sucessor(signer: signer) {
        // The successor is red and is the left child of the node getting deleted.
        let tree = test_tree(vector<u128>[10, 5, 15, 7]);
        assert_inorder_tree(&tree, b"5(B) 10 _ 7: [0], 7(R) 5 _ _: [0], 10(B) root 5 15: [0], 15(B) 10 _ _: [0]");
        delete(&mut tree, 5);
        assert_inorder_tree(&tree, b"7(B) 10 _ _: [0], 10(B) root 7 15: [0], 15(B) 10 _ _: [0]");
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
        assert_inorder_tree(&tree, b"30(B) 40 _ 35: [0], 35(R) 30 _ _: [0], 40(B) root 30 50: [0], 50(B) 40 _ _: [0]");
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
        assert_inorder_tree(&tree, b"1(B) 2 _ _: [0], 2(B) root 1 10: [0], 3(B) 10 _ _: [0], 10(R) 2 3 20: [0], 20(B) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3_2_c_ii(signer: signer) {
        let tree = test_tree(vector<u128>[20, 10, 30, 45, 50, 55]);
        delete(&mut tree, 10);
        assert_inorder_tree(&tree, b"20(B) 45 _ 30: [0], 30(R) 20 _ _: [0], 45(B) root 20 50: [0], 50(B) 45 _ 55: [0], 55(R) 50 _ _: [0]");
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
            assert!(keyCount<u128>(&tree) == i + 1, 0);
            assert_red_black_tree(&tree);
            i = i + 1;
        };
        while (i > 0) {
            i = i - 1;
            delete(&mut tree, i);
            assert!(!contains_key(&tree, i), 0);
            assert!(keyCount<u128>(&tree) == i, 0);
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
            assert!(keyCount<u128>(&tree) == count - i, 0);
            assert_red_black_tree(&tree);
        };
        while (i < count) {
            delete(&mut tree, i);
            assert!(!contains_key(&tree, i), 0);
            assert!(keyCount<u128>(&tree) == count - i - 1, 0);
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
            let keyCountBeforeDeletion = keyCount<u128>(&tree);
            delete(&mut tree, key);
            assert!(keyCountBeforeDeletion == keyCount<u128>(&tree) + 1, 0);
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
        string::append(buffer, string::utf8(if (is_red(tree, key)) b"(R)" else b"(B)"));
        if (node.parentNodeKeyIsSet) {
            string::append(buffer, string::utf8(b" "));
            string::append(buffer, to_string_u128(node.parentNodeKey));
        } else if (node.key == tree.rootNodeKey){
            string::append(buffer, string::utf8(b" root"));
        } else {
            string::append(buffer, string::utf8(b" ?"));
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
            // Condition 4: There are no two adjacent red nodes (A red node cannot have a red parent or red child).
            assert_no_two_adjacent_red_nodes_inorder<u128>(tree, tree.rootNodeKey);
            // Condition 5: Every path from a node (including root) to any of its descendants leaf nodes has the same
            // number of black nodes.
            assert_black_node_depth_starting_node<u128>(tree, tree.rootNodeKey);
        };
        // Condition 6: All leaf nodes are black nodes [no need to check].
    }

    #[test_only]
    fun assert_correct_node_keys<V: store + drop>(tree: &Tree<V>, currentNodeKey: u128) {
        let currentNode = node_with_key(tree, currentNodeKey);
        if (currentNode.parentNodeKeyIsSet) {
            let parentNode = node_with_key(tree, currentNode.parentNodeKey);
            assert!(parentNode.key == currentNode.parentNodeKey, 0)
        };
        if (currentNode.leftChildNodeKeyIsSet) {
            let leftChildNode = node_with_key(tree, currentNode.leftChildNodeKey);
            assert!(leftChildNode.key == currentNode.leftChildNodeKey, 0);
            assert_correct_node_keys(tree, currentNode.leftChildNodeKey);
        };
        if (currentNode.rightChildNodeKeyIsSet) {
            let rightChildNode = node_with_key(tree, currentNode.rightChildNodeKey);
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
        let currentNode = node_with_key(tree, currentNodeKey);
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
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_parent(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        node_with_key_mut<u128>(&mut tree, 15).parentNodeKeyIsSet = true;
        node_with_key_mut<u128>(&mut tree, 15).parentNodeKey = 100;
        assert_correct_node_keys(&tree, tree.rootNodeKey);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_left_child(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        node_with_key_mut<u128>(&mut tree, 15).leftChildNodeKeyIsSet = true;
        node_with_key_mut<u128>(&mut tree, 15).leftChildNodeKey = 100;
        assert_correct_node_keys(&tree, tree.rootNodeKey);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_correct_node_keys_with_invalid_right_child(signer: signer) {
        let tree = test_tree(vector<u128>[10, 15, 25]);
        node_with_key_mut<u128>(&mut tree, 15).rightChildNodeKeyIsSet = true;
        node_with_key_mut<u128>(&mut tree, 15).rightChildNodeKey = 100;
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
        mark_black(&mut tree, 25);
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