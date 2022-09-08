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
    const INVALID_KEY_ACCESS: u64 = 4;

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

    fun has_parent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = node_with_key(tree, nodeKey);
        node.parentNodeKeyIsSet
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
            (true, min_node_key_starting_at_node(tree, nodeKey))
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
        let leftChildKey = right_child_key(tree, nodeKey);
        is_red(tree, leftChildKey)
    }

    fun has_red_child<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        has_right_child(tree, nodeKey) && is_right_child_red(tree, nodeKey) ||
            has_left_child(tree, nodeKey) && is_left_child_red(tree, nodeKey)
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
            tree.length = tree.length + 1;
            tree.rootNodeKey = key;
            table::add(&mut tree.nodes, key, rootNode);
        } else {
            // Otherwise, recursively insert starting at the root node.
            let rootNodeKey = tree.rootNodeKey;
            insert_starting_at_node(tree, key, value, rootNodeKey);
        };
        // In case any red/black invariants were broken, fix it up!
        fix_up_insertion(tree, key)
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
            // By default, all new nodes are red!
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

    public fun delete_node<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        let _log = nodeKey == 5;

        if (is_leaf_node(tree, nodeKey)) {
            // Case 1: Handle leaf node case. If it's the root, just delete the node. Otherwise, if
            // the deleted node is black, there must be an imbalance; fix the double black!
            if (is_root_node(tree, nodeKey)) {
                drop_node(tree, nodeKey);
            } else if (is_black(tree, nodeKey)) {
                // The deletion of a black leaf causes an imbalance!
                fix_double_black(tree, nodeKey);
            };
            drop_node(tree, nodeKey);
        } else if (has_left_child(tree, nodeKey) || has_right_child(tree, nodeKey)) {
            let (_, successorKey) = successor_key(tree, nodeKey);
            // Case 2: Handle a deletion of the root node, with only a single child.
            // The root node is always black, so removing it subtracts -1 black from depth.
            // We make it's successsor black, and even out the number.
            if (is_root_node(tree, nodeKey)) {
                let successorNode = node_with_key_mut(tree, successorKey);
                successorNode.parentNodeKeyIsSet = false;
                successorNode.isRed = false;
                tree.rootNodeKey = successorNode.key;
                drop_node(tree, nodeKey);
            } else {
                // Case 3: We have one successor, and we're not the rood node. If either
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
        } else  {
            // Case 4: We have two children. What we want to do is find a succesor which
            // by definintion will have at most one child, then swap it out with the current node.
            // After the swap, the deletion should be handled by one of the 1 - 3 cases.
            // TODO: Make it happen!
            let (_, successorKey) = successor_key(tree, nodeKey);

            if (is_root_node(tree, nodeKey)) {

            };

            if (has_left_child(tree, nodeKey)) {
                let leftChildNodeKey = left_child_key(tree, nodeKey);
                let successorNode = node_with_key_mut(tree, successorKey);
                successorNode.leftChildNodeKey = leftChildNodeKey;
                successorNode.leftChildNodeKeyIsSet = true;

            }
        }
    }

    fun fix_double_black<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (is_root_node(tree, nodeKey)) {
            return
        };
        let parentNodeKey = parent_node_key(tree, nodeKey);
        if (has_sibiling(tree, nodeKey)) {
            let sibilingNodeKey = sibiling_node_key(tree, nodeKey);
            if (is_red(tree, sibilingNodeKey)) {
                mark_red(tree, parentNodeKey);
                mark_black(tree, sibilingNodeKey);
                if (is_left_child(tree, sibilingNodeKey, parentNodeKey)) {
                    rotate_right(tree, parentNodeKey, sibilingNodeKey);
                } else {
                    rotate_left(tree, parentNodeKey, sibilingNodeKey);
                };
                fix_double_black(tree, nodeKey);
            } else {
                if (has_red_child(tree, sibilingNodeKey)) {
                    if (has_left_child(tree, sibilingNodeKey) && is_left_child_red(tree, sibilingNodeKey)) {
                        if (is_left_child(tree, sibilingNodeKey, parentNodeKey)) {
                            // left left case
                            let isSibilingRed = is_red(tree, sibilingNodeKey);
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingLeftChildNodeKey = left_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingLeftChildNodeKey, isSibilingRed);
                            mark_color(tree, sibilingNodeKey, isParentRed);
                            rotate_right(tree, parentNodeKey, sibilingNodeKey);
                        } else {
                            // right left case
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingLeftChildNodeKey = left_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingLeftChildNodeKey, isParentRed);
                            rotate_right(tree, sibilingNodeKey, sibilingLeftChildNodeKey);
                            rotate_left(tree, parentNodeKey, sibilingNodeKey);
                        }
                    } else {
                        if (is_left_child(tree, sibilingNodeKey, parentNodeKey)) {
                            // left right case
                            let isParentRed = is_red(tree, parentNodeKey);
                            let sibilingRightChildNodeKey = right_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingRightChildNodeKey, isParentRed);
                            rotate_left(tree, sibilingNodeKey, sibilingRightChildNodeKey);
                            rotate_left(tree, parentNodeKey, sibilingNodeKey);
                        } else {
                            // right right case
                            let isParentRed = is_red(tree, parentNodeKey);
                            let isSibilingRed = is_red(tree, sibilingNodeKey);
                            let sibilingRightChildKey = right_child_key(tree, sibilingNodeKey);
                            mark_color(tree, sibilingRightChildKey, isSibilingRed);
                            mark_color(tree, sibilingNodeKey, isParentRed);
                            rotate_left(tree, parentNodeKey, sibilingNodeKey);
                        }
                    }
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
        table::remove(&mut tree.nodes, key);
        tree.length = tree.length - 1
        // TODO: need to unpoint the parent
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_nodes(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 15, 0);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) root 5 15: [0], 15(R) 10 _ _: [0]");
        delete_node(&mut tree, 5);
        assert_inorder_tree(&tree, b"10(B) root _ 15: [0], 15(R) 10 _ _: [0]");
        delete_node(&mut tree, 15);
        assert_inorder_tree(&tree, b"10(B) root _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_nodes_with_single_children(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 3, 0);
        insert(&mut tree, 18, 0);
        assert_inorder_tree(&tree, b"3(R) 5 _ _: [0], 5(B) 10 3 _: [0], 10(B) root 5 15: [0], 15(B) 10 _ 18: [0], 18(R) 15 _ _: [0]");
        delete_node(&mut tree, 5);
        assert_inorder_tree(&tree, b"3(B) 10 _ _: [0], 10(B) root 3 15: [0], 15(B) 10 _ 18: [0], 18(R) 15 _ _: [0]");
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
        let tree = new<u128>();
        insert(&mut tree, 8, 0);
        insert(&mut tree, 6, 0);
        insert(&mut tree, 7, 0);
        insert(&mut tree, 9, 0);
        insert(&mut tree, 5, 0);
        assert_inorder_tree(&tree, b"5(R) 6 _ _: [0], 6(B) 7 5 _: [0], 7(B) root 6 8: [0], 8(B) 7 _ 9: [0], 9(R) 8 _ _: [0]");
        swap_parents(&mut tree, 8, 9);
        swap_parents(&mut tree, 6, 5);
        let rootNode = root_node(&tree);
        assert!(rootNode.rightChildNodeKey == 9, 0);
        assert!(rootNode.leftChildNodeKey == 5, 0);
        assert!(is_root_node(&tree, 7), 0);
        move_to(&signer, tree)
    }

    ///
    /// FIXUPS
    ///

    // Mostly, following the guidelines here: https://www.programiz.com/dsa/insertion-in-a-red-black-tree.
    // It's much easier to follow the code from the above link, that than the diagrams & annotations.
    // Also note that in the tutorial's code, the diagram's and the code have the top level if statement flipped.
    // If you're using, good visualization here: https://www.cs.usfca.edu/~galles/visualization/RedBlack.html.
    fun fix_up_insertion<V: store + drop>(tree: &mut Tree<V>, currentNodeKey: u128) {
        let log = currentNodeKey == 1;
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
                if (log) std::debug::print(&1);
                // 3. Case-I: If the left uncle is black, then mark both parents as black, and grandparent as red.
                if (has_left_child(tree, grandparentNodeKey) && is_left_child_red(tree, grandparentNodeKey) ) {
                    mark_children_black(tree, grandparentNodeKey);
                    mark_red(tree, grandparentNodeKey);
                    currentNodeKey = grandparentNodeKey;
                } else {
                    if (log) std::debug::print(&2);
                    // 3. Case-II: Else if current node is the left child of the parent node, then right rotate the
                    // current node and parent node, then assign parent to be the new current node.
                    if (is_left_child(tree, currentNodeKey, parentNodeKey)) {
                        rotate_right(tree, parentNodeKey, currentNodeKey);
                        currentNodeKey = parentNodeKey;
                        if (log) std::debug::print(&4);
                    };
                    if (log) std::debug::print(&5);
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

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_1_1(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 31, 0);
        assert_inorder_tree(&tree, b"15(R) 21 _ _: [0], 21(B) root 15 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 10, 0);
        assert_inorder_tree(&tree, b"10(R) 15 _ _: [0], 15(B) 21 10 _: [0], 21(B) root 15 31: [0], 31(B) 21 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_1_2(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 6, 0);
        assert_inorder_tree(&tree, b"5(R) 6 _ _: [0], 6(B) 21 5 10: [0], 10(R) 6 _ _: [0], 21(B) root 6 31: [0], 31(B) 21 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_1_3(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 10, 0);
        assert_inorder_tree(&tree, b"10(R) 15 _ _: [0], 15(B) 21 10 _: [0], 21(B) root 15 31: [0], 31(B) 21 _ _: [0]");
        insert(&mut tree, 5, 0);
        assert_inorder_tree(&tree, b"5(R) 10 _ _: [0], 10(B) 21 5 15: [0], 15(R) 10 _ _: [0], 21(B) root 10 31: [0], 31(B) 21 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_2_1t(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        assert_inorder_tree(&tree, b"10(R) 21 _ _: [0], 21(B) root 10 31: [0], 31(R) 21 _ _: [0]");
        insert(&mut tree, 41, 0);
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 31: [0], 31(B) 21 _ 41: [0], 41(R) 31 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_2_2(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 41, 0);
        insert(&mut tree, 35, 0);
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 35: [0], 31(R) 35 _ _: [0], 35(B) 21 31 41: [0], 41(R) 35 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_case_2_3(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 21, 0);
        insert(&mut tree, 10, 0);
        insert(&mut tree, 31, 0);
        insert(&mut tree, 41, 0);
        insert(&mut tree, 51, 0);
        assert_inorder_tree(&tree, b"10(B) 21 _ _: [0], 21(B) root 10 41: [0], 31(R) 41 _ _: [0], 41(B) 21 31 51: [0], 51(R) 41 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_fix_up_insertion_deep(signer: signer) {
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
        move_to(&signer, tree)
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
    // TEST ROTATIONS
    //

    #[test(signer = @0x345)]
    fun test_rotate_right_with_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 7, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 8, 0);
        insert(&mut tree, 2, 0);
        insert(&mut tree, 6, 0);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) 10 5 8: [0], 8(B) 7 _ _: [0], 10(B) root 7 15: [0], 15(B) 10 _ _: [0]");
        rotate_right(&mut tree, 10, 7);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) root 5 10: [0], 8(B) 10 _ _: [0], 10(B) 7 8 15: [0], 15(B) 10 _ _: [0]");
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_right(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 7, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 5, 0);
        insert(&mut tree, 8, 0);
        insert(&mut tree, 2, 0);
        insert(&mut tree, 6, 0);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 7 2 6: [0], 6(R) 5 _ _: [0], 7(R) 10 5 8: [0], 8(B) 7 _ _: [0], 10(B) root 7 15: [0], 15(B) 10 _ _: [0]");
        rotate_right(&mut tree, 7, 5);
        assert_inorder_tree(&tree, b"2(R) 5 _ _: [0], 5(B) 10 2 7: [0], 6(R) 7 _ _: [0], 7(R) 5 6 8: [0], 8(B) 7 _ _: [0], 10(B) root 5 15: [0], 15(B) 10 _ _: [0]");
        assert!(is_root_node(&tree, 10), 0);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_rotate_right_with_incorrect_nodes(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 4, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 14, 0);
        insert(&mut tree, 16, 0);
        rotate_right(&mut tree, 10, 16);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_rotate_left_with_root(signer: signer) {
        let tree = new<u128>();
        insert(&mut tree, 10, 0);
        insert(&mut tree, 4, 0);
        insert(&mut tree, 15, 0);
        insert(&mut tree, 14, 0);
        insert(&mut tree, 16, 0);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 10, 15);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) 15 4 14: [0], 14(R) 10 _ _: [0], 15(B) root 10 16: [0], 16(R) 15 _ _: [0]");
        assert!(is_root_node(&tree, 15), 0);
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
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 15: [0], 14(R) 15 _ _: [0], 15(B) 10 14 16: [0], 16(R) 15 _ _: [0]");
        rotate_left(&mut tree, 15, 16);
        assert_inorder_tree(&tree, b"4(B) 10 _ _: [0], 10(B) root 4 16: [0], 14(R) 15 _ _: [0], 15(B) 16 14 _: [0], 16(R) 10 15 _: [0]");
        assert!(is_root_node(&tree, 10), 0);
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

    //
    // TEST INSERTIONS
    //

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
        assert_inorder_tree(&tree, b"8(R) 10 _ _: [10, 1], 10(B) root 8 _: [10]");
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
        assert_inorder_tree(&tree, b"10(B) root _ 12: [10], 12(R) 10 _ _: [100, 1000]");
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
        assert_inorder_tree(&tree, b"8(R) 10 _ _: [10], 10(B) root 8 _: [100]");
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
        assert_inorder_tree(&tree, b"6(R) 8 _ _: [1], 8(B) root 6 10: [10], 10(R) 8 _ _: [100]");
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
        assert!(length<u128>(&tree) == 3, 0);
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
        assert!(length<u128>(&tree) == 4, 0);
        assert_inorder_tree(&tree, b"6(R) 8 _ _: [5], 8(B) 10 6 _: [10], 10(B) root 8 12: [100], 12(B) 10 _ _: [1000]");
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

    //
    // TEST ONLY FUNCTIONS
    //

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
        assert!(!is_red(tree, tree.rootNodeKey), 0)
        // TODO: Add the rest of the conditions!
    }
}