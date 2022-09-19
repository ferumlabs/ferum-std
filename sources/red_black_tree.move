/// ---
/// description: ferum_std::red_black_tree
/// ---
///
/// Ferum's implementation of a [Red Black Tree](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree).
/// A red black tree is a self balancing binary tree which performs rotations tree manipulations to maintain a tree
/// height of log(k), where k is the number of keys in the tree. Values with duplicate keys can be inserted into the
/// tree - each value will stored in a linked list on each tree node. When a node no longer has any values, the node
/// is removed (this is referred to as key deletion). The tree only supports u128 keys because (as of writing) move
/// has no way to define comparators for generic types.
///
/// The tree supports the following operations with the given time complexities:
///
/// | Operation                            | Time Complexity |
/// |--------------------------------------|-----------------|
/// | Deletion of value                    | O(1)            |
/// | Deletion of key                      | O(log(n))       |
/// | Insertion of value with new key      | O(log(n))       |
/// | Insertion of value with existing key | O(1)            |
/// | Retrieval of min/max key             | O(1)            |
///
/// # Quick Example
///
/// ```
/// use ferum_std::red_black_tree::{Self, Tree};
///
/// // Create a tree with u128 values.
/// let tree = red_black_tree::new<u128>();
///
/// // Insert
/// red_black_tree::insert(&mut tree, 100, 50);
/// red_black_tree::insert(&mut tree, 100, 40);
/// red_black_tree::insert(&mut tree, 120, 10);
/// red_black_tree::insert(&mut tree, 90, 5);
///
/// // Get min/max
/// let min = red_black_tree::min_key(&tree);
/// assert!(min == 90, 0);
/// let max = red_black_tree::max_key(&tree);
/// assert!(max == 90, 0);
///
/// // Delete values and keys.
/// red_black_tree::delete_value(&mut tree, 100, 40);
/// red_black_tree::delete_key(&mut tree, 90);
/// let min = red_black_tree::min_key(&tree);
/// assert!(min == 100, 0);
/// ```
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

    /// Thrown when trying to perform an operation on the tree that requires the tree to be non empty.
    const TREE_IS_EMPTY: u64 = 0;
    /// Thrown when trying to perform an operation for a specific key but the key is not set.
    const KEY_NOT_SET: u64 = 1;
    const NODE_NOT_FOUND: u64 = 2;
    /// Thrown when trying to perform an invalid rotation on the tree.
    const INVALID_ROTATION_NODES: u64 = 3;
    const INVALID_KEY_ACCESS: u64 = 4;
    /// Thrown when trying to get the successor for a leaf node.
    const SUCCESSOR_FOR_LEAF_NODE: u64 = 5;
    /// Thrown when the edges being swapped doesn't define a valid edge direction.
    const INVALID_OUTGOING_SWAP_EDGE_DIRECTION: u64 = 6;
    /// Thrown when trying to add a non leaf node to the tree.
    const ONLY_LEAF_NODES_CAN_BE_ADDED: u64 = 7;
    /// Thrown when trying fix a double red but the tree doesn't follow the correct structure.
    const INVALID_FIX_DOUBLE_RED_OPERATION: u64 = 8;
    /// Thrown when trying to perform an operation on a leaf node but that node has a left child.
    const INVALID_LEAF_NODE_HAS_LEFT_CHILD: u64 = 9;
    /// Thrown when trying to perform an operation on a leaf node but that node has a right child.
    const INVALID_LEAF_NODE_HAS_RIGHT_CHILD: u64 = 10;
    /// Thrown when trying to perform an operation on a leaf node but that node has no parent.
    const INVALID_LEAF_NODE_NO_PARENT: u64 = 11;

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

    //
    // PUBLIC CONSTRUCTORS
    //

    /// Creates a new tree.
    public fun new<V: store + drop>(): Tree<V> {
        Tree<V> { keyCount: 0, valueCount: 0, rootNodeKey: 0, nodes: table::new<u128, Node<V>>()}
    }

    //
    // PUBLIC ACCESSORS
    //

    /// Returns if the tree is empty.
    public fun is_empty<V: store + drop>(tree: &Tree<V>): bool {
        tree.keyCount == 0
    }

    /// Returns how many keys are in the tree.
    public fun key_count<V: store + drop>(tree: &Tree<V>): u128 {
        tree.keyCount
    }

    public fun peek<V: store + drop>(tree: &Tree<V>): (u128, &V) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        let rootNode = root_node(tree);
        let rootNodeFirstValue = vector::borrow<V>(&rootNode.values, 0);
        (tree.rootNodeKey, rootNodeFirstValue)
    }

    /// Returns true if the tree has at least one value with the given key.
    public fun contains_key<V: store + drop>(tree: &Tree<V>, key: u128): bool {
        table::contains(&tree.nodes, key)
    }

    /// Returns the first value with the givem key.
    public fun first_value_at<V: store + drop>(tree: &Tree<V>, key: u128): &V {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(contains_key(tree, key), KEY_NOT_SET);
        let node = get_node(tree, key);
        vector::borrow<V>(&node.values, 0)
    }

    /// Returns all the values with the given key.
    public fun values_at<V: store + drop>(tree: &Tree<V>, key: u128): &vector<V> {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(contains_key(tree, key), KEY_NOT_SET);
        let node = get_node(tree, key);
        &node.values
    }

    //
    // PRIVATE ACCESSORS
    //

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

    fun is_root_node<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        tree.rootNodeKey == nodeKey
    }

    fun set_root_node<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = get_node_mut(tree, nodeKey);
        node.parentNodeKeyIsSet = false;
        tree.rootNodeKey = nodeKey;
    }

    fun has_parent<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        let node = get_node(tree, nodeKey);
        node.parentNodeKeyIsSet
    }

    fun parent_node_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let node = get_node(tree, nodeKey);
        node.parentNodeKey
    }

    fun get_parent<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        let parentKey = table::borrow(&tree.nodes, key).parentNodeKey;
        table::borrow(&tree.nodes, parentKey)
    }

    fun get_parent_mut<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128): &mut Node<V> {
        assert!(has_parent(tree, nodeKey), INVALID_KEY_ACCESS);
        let parentKey = parent_node_key(tree, nodeKey);
        get_node_mut(tree, parentKey)
    }

    fun mark_color<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128, isRed: bool) {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node_mut(tree, nodeKey).isRed = isRed;
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

    fun has_sibling<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        if (has_parent(tree, nodeKey)) {
            let parentNodeKey = parent_node_key(tree, nodeKey);
            let parent = get_node(tree, parentNodeKey);
            return parent.leftChildNodeKeyIsSet && parent.rightChildNodeKeyIsSet
        };
        false
    }

    fun get_sibling<V: store + drop>(tree: &Tree<V>, key: u128): &Node<V> {
        let parent = get_parent(tree, key);

        if (parent.leftChildNodeKeyIsSet && parent.leftChildNodeKey == key) {
            // Sibling is the right child of the parent.
            let siblingKey = parent.rightChildNodeKey;
            get_node(tree, siblingKey)
        } else {
            assert!(parent.rightChildNodeKeyIsSet && parent.rightChildNodeKey == key, 0);
            // Sibling is the left child of the parent.
            let siblingKey = parent.leftChildNodeKey;
            get_node(tree, siblingKey)
        }
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


    public fun delete_value<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128, _value: V) {
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
    }

    // The code in GeeksForGeeks has many bugs, use the discussion board to see them.
    // https://www.geeksforgeeks.org/red-black-tree-set-3-delete-2/
    public fun delete<V: store + drop>(tree: &mut Tree<V>, nodeKey: u128) {
        if (!table::contains(&tree.nodes, nodeKey)) {
            // Nothing to delete.
            return
        };

        if (tree.keyCount == 1) {
            // Leaf node that is also the root. Just remove the node from the tree.
            table::remove(&mut tree.nodes, nodeKey);
            tree.keyCount = 0;
            tree.rootNodeKey = 0;
            return
        };

        let node = get_node(tree, nodeKey);
        if (!node.leftChildNodeKeyIsSet && !node.rightChildNodeKeyIsSet) {
            // A leaf node. Can't be root because we already accounted for that case above.
            remove_leaf_node(tree, nodeKey);
            return
        };

        // Not a leaf node. First swap with successor. This makes the node a leaf node.
        // So we can delete it in the same way as above.
        let nodeKey = node.key;
        swap_with_successor(tree, nodeKey);

        // It's not gauranteed that the node is a leaf node at this point because multiple successor swaps might
        // be neccesary. We can just call delete again to cover that case.
        delete(tree, nodeKey);
    }

    fun remove_leaf_node<V: store + drop>(tree: &mut Tree<V>, key: u128) {
        let node = get_node(tree, key);
        assert!(!node.leftChildNodeKeyIsSet, INVALID_LEAF_NODE_HAS_LEFT_CHILD);
        assert!(!node.rightChildNodeKeyIsSet, INVALID_LEAF_NODE_HAS_RIGHT_CHILD);
        assert!(node.parentNodeKeyIsSet, INVALID_LEAF_NODE_NO_PARENT);

        // If the node is red, removing it will not have affected tree invariants.
        // If the node is black, we need to account for the missing black. We do this
        // by marking the node to be deleted as double black, which we then fix via `fix_double_black`.
        if (!node.isRed) {
            fix_double_black(tree, key);
        };

        // After fixing the double black, we can actually delete the node.
        let node = table::remove(&mut tree.nodes, key);
        tree.keyCount = tree.keyCount - 1;

        // Disconnect node from parent.
        let parentKey = node.parentNodeKey;
        let parent = get_node_mut(tree, parentKey);
        if (parent.leftChildNodeKeyIsSet && parent.leftChildNodeKey == node.key) {
            parent.leftChildNodeKeyIsSet = false
        } else {
            parent.rightChildNodeKeyIsSet = false
        };
    }

    // When deleting, we potentially create double black node. The node that is doublle black is kept track of
    // in this function (ie it's not stored on the node). To resolve duoble blacks, we perform
    // transformations on the tree until the double black is removed.
    //
    // There are multiple cases and corresponding actions. Each case's set of actions either moves the
    // double black node up the tree, transforms the tree into another case, or removes the double black.
    //
    // Legend:
    //
    // 2Blk = Double black node
    // Blk = Black node
    // Red = Red node
    // Color = Variable for unknown color (either red or black)
    // *Blk = Inferred black node due to tree invariants
    // T# = Subtree, which could be empty
    // PN = Parent node
    // CN = Current node
    // S = Sibling node
    // SCA = Sibling child closest to CN, which could be nil
    // SCB = Sibling child farthest from CN, which could be nil
    //
    // Cases:
    //
    // Case 0 (no sibling):
    //  - Make PN Blk if it was Red. Otherwise, make it 2Blk
    //
    // Case 1 (sibling is red):
    //  - Swap color of PN and S
    //  - Rotate PN in direction of CN
    //
    //            PN (Color)                                  S (Color)
    //           /  \                                        / \
    //  (2Blk) CN    \                               (Red) PN   T4 (*Blk)
    //        / \     \                                   / \
    //       T1  T2    S (Red)       ------>     (2Blk) CN  T3 (*Blk)
    //                / \                              /  \
    //        (*Blk) T3  T4 (*Blk)                   T1   T2
    //
    // Case 2 (sibling and sibling's children are black):
    //  - Make CN Blk
    //  - Make S Red
    //  - Make PN Blk if it was Red. Otherwise, make it 2Blk
    //
    //            PN (Color)                             PN (Blk if Color == Red, else 2Blk)
    //           / \                                    / \
    //  (2Blk) CN   \                           (Blk) CN   \
    //        / \    \                               / \    \
    //       T1  T2   S (Blk)       ------>         T1  T2   S (Red)
    //               / \                                    / \
    //       (Blk) SCA  \                           (Blk) SCA  \
    //             / \   SCB (Blk)                        / \   SCB (Blk)
    //           T3  T4  / \                            T3  T4  / \
    //                 T5  T6                                 T5  T6
    //
    // Case 3 (sibling (S) is black, closest sibling's child (SCA) is Red):
    //  - Swap S and SCA color
    //  - Rotate S sway from CN
    //
    //            PN (Color)                             PN (Color)
    //           / \                                    / \
    //  (2Blk) CN   \                           (2Blk) CN  \
    //        / \    \                                / \   \
    //       T1  T2   S (Blk)       ------>         T1  T2  SCA (Blk)
    //               /  \                                   / \
    //      (Red) SCA    SCB (Blk)                 (*Blk) T3   \
    //            / \     / \                                   S (Red)
    //   (*Blk) T3   \   T5  T6                                / \
    //                \                               (*Blk) T4  SCB (Blk)
    //              T4 (*Blk)                                     / \
    //                                                           T5  T6
    //
    // Case 4 (sibling (S) is black, closest sibling's child (SCA) is Blk):
    //  - Swap color of PN and S
    //  - Rotate PN towards CN
    //  - Make CN Blk
    //  - Make SCB Blk
    //
    //            PN (Color)                                S (Color)
    //           / \                                       /  \
    //  (2Blk) CN   \                                     /    SCB (Blk)
    //        / \    \                                   /      /  \
    //       T1  T2   S (Blk)       ------>       (Blk) PN    T5    T6 (*Blk)
    //               / \                              /   \   (*Blk)
    //       (Blk) SCA  \                            /     \
    //             / \   SCB (Red)            (Blk) CN      SCA (Blk)
    //           T3  T4  / \                       / \      / \
    //                  /   \                    T1  T2    T3 T4
    //          (*Blk) T5   T6 (*Blk)
    //
    fun fix_double_black<V: store + drop>(tree: &mut Tree<V>, key: u128) {
        while (true) {
            let node = get_node(tree, key);
            if (!node.parentNodeKeyIsSet) {
                // This is the root node. No need for any other action.
                break
            };

            if (!has_sibling(tree, key)) {
                // Case 0 (no sibling)
                //  - Make PN Blk if it was Red. Otherwise, make it 2Blk
                let parent = get_parent_mut(tree, key);
                if (parent.isRed) {
                    // If parent is red, there is no longer a double black so we can return.
                    parent.isRed = false;
                    return
                };
                // Otherwise, parent is now the double black.
                parent.isRed = false;
                key = parent.key;
                continue
            } else {
                // Sibling information.
                let sibling = get_sibling(tree, key);
                let siblingKey = sibling.key;
                let siblingIsRed = sibling.isRed;
                let siblingHasLeftChild = sibling.leftChildNodeKeyIsSet;
                let siblingLeftChildKey = sibling.leftChildNodeKey;
                let siblingHasRightChild = sibling.rightChildNodeKeyIsSet;
                let siblingRightChildKey = sibling.rightChildNodeKey;

                // Parent information.
                let parent = get_parent(tree, key);
                let parentKey = parent.key;
                let parentIsRed = parent.isRed;
                let node = get_node(tree, key);
                let isLeftChild = is_left_child(node, parent);

                let siblingLeftChildIsRed = siblingHasLeftChild && get_node(tree, siblingLeftChildKey).isRed;
                let siblingRightChildIsRed = siblingHasRightChild && get_node(tree, siblingRightChildKey).isRed;

                if (siblingIsRed) {
                    // Case 1 (sibling is red):
                    //  - Swap color of PN and S
                    //  - Rotate PN in direction of CN
                    //
                    //            PN (Color)                                 S (Color)
                    //           /  \                                       / \
                    //  (2Blk) CN    \                              (Red) PN   T4 (*Blk)
                    //        / \     \                                  / \
                    //       T1  T2    S (Red)       ------>    (2Blk) CN  T3 (*Blk)
                    //                / \                             /  \
                    //        (*Blk) T3  T4 (*Blk)                  T1   T2
                    //

                    // Make PN red
                    get_node_mut(tree, parentKey).isRed = true;

                    // Make S color of parent.
                    get_node_mut(tree, siblingKey).isRed = parentIsRed;

                    // Rotate towards CN.
                    if (isLeftChild) {
                        rotate_left(tree, parentKey, siblingKey);
                    } else {
                        rotate_right(tree, parentKey, siblingKey);
                    };
                    continue
                } else if (!siblingRightChildIsRed && !siblingLeftChildIsRed) {
                    // Case 2 (sibling and sibling's children are black):
                    //  - Make CN Blk
                    //  - Make S Red
                    //  - Make PN Blk if it was Red. Otherwise, make it 2Blk
                    //
                    //            PN (Color)                           PN (Blk if Color == Red, else 2Blk)
                    //           / \                                  / \
                    //  (2Blk) CN   \                         (Blk) CN   \
                    //        / \    \                             / \    \
                    //       T1  T2   S (Blk)       ------>       T1  T2   S (Red)
                    //               / \                                  / \
                    //       (Blk) SCA  \                         (Blk) SCA  \
                    //             / \   SCB (Blk)                      / \   SCB (Blk)
                    //           T3  T4  / \                          T3  T4  / \
                    //                 T5  T6                               T5  T6
                    //

                    // Make S red.
                    get_node_mut(tree, siblingKey).isRed = true;

                    // Make PN Blk if it was Red, otherwise mark it as 2Blk.
                    let parent = get_parent_mut(tree, key);
                    if (parent.isRed) {
                        parent.isRed = false;
                        // No more 2Blk!
                        return
                    } else {
                        parent.isRed = false;
                        key = parent.key;
                        continue
                    }
                } else if (isLeftChild && siblingLeftChildIsRed || !isLeftChild && siblingRightChildIsRed) {
                    // Case 3 (sibling (S) is black, closest sibling's child (SCA) is Red):
                    //  - Swap S and SCA color
                    //  - Rotate S sway from CN
                    //
                    //            PN (Color)                            PN (Color)
                    //           / \                                   / \
                    //  (2Blk) CN   \                          (2Blk) CN  \
                    //        / \    \                               / \   \
                    //       T1  T2   S (Blk)       ------>        T1  T2  SCA (Blk)
                    //               /  \                                  / \
                    //      (Red) SCA    SCB (Blk)                (*Blk) T3   \
                    //            / \     / \                                  S (Red)
                    //   (*Blk) T3   \   T5  T6                               / \
                    //                \                              (*Blk) T4  SCB (Blk)
                    //              T4 (*Blk)                                    / \
                    //                                                            T5  T6
                    //

                    if (isLeftChild) {
                        // Swap colors.
                        get_node_mut(tree, siblingKey).isRed = true;
                        get_node_mut(tree, siblingLeftChildKey).isRed = false;

                        get_node_mut(tree, siblingLeftChildKey).isRed = false;
                        rotate_right(tree, siblingKey, siblingLeftChildKey);
                    } else {
                        // Swap colors.
                        get_node_mut(tree, siblingKey).isRed = true;
                        get_node_mut(tree, siblingRightChildKey).isRed = false;
                        rotate_left(tree, siblingKey, siblingRightChildKey);
                    };
                    continue
                } else if (isLeftChild && !siblingLeftChildIsRed || !isLeftChild && !siblingRightChildIsRed) {
                    // Case 4 (sibling (S) is black, closest sibling's child (SCA) is Blk):
                    //  - Swap color of PN and S
                    //  - Rotate PN towards CN
                    //  - Make CN Blk
                    //  - Make SCB Blk
                    //
                    //            PN (Color)                               S (Color)
                    //           / \                                      /  \
                    //  (2Blk) CN   \                                    /    SCB (Blk)
                    //        / \    \                                  /      /  \
                    //       T1  T2   S (Blk)       ------>      (Blk) PN    T5    T6 (*Blk)
                    //               / \                             /   \   (*Blk)
                    //       (Blk) SCA  \                           /     \
                    //             / \   SCB (Red)           (Blk) CN      SCA (Blk)
                    //           T3  T4  / \                      / \      / \
                    //                  /   \                   T1  T2    T3 T4
                    //          (*Blk) T5   T6 (*Blk)
                    //

                    // Swap PN and S colors.
                    get_node_mut(tree, siblingKey).isRed = parentIsRed;
                    get_node_mut(tree, parentKey).isRed = false;

                    // Rotate PN towards CN.
                    if (isLeftChild) {
                        rotate_left(tree, parentKey, siblingKey);
                    } else {
                        rotate_right(tree, parentKey, siblingKey);
                    };

                    // Make SCB Blk.
                    if (isLeftChild && siblingHasRightChild) {
                        get_node_mut(tree, siblingRightChildKey).isRed = false;
                    } else if (!isLeftChild && siblingHasLeftChild) {
                        get_node_mut(tree, siblingLeftChildKey).isRed = false;
                    };

                    // No more 2Blk!
                    return
                }
            }
        }
    }

    //
    // SUCCESSOR SWAPPING
    //

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
        assert!(has_left_child(tree, nodeKey) || has_right_child(tree, nodeKey), SUCCESSOR_FOR_LEAF_NODE);
        let successor = get_successor(tree, nodeKey);
        let successorKey = successor.key;
        let isSuccessorRed = successor.isRed;

        let successorOutgoingEdges = get_outgoing_edges(tree, successor);
        let node = get_node(tree, nodeKey);
        let isNodeRed = node.isRed;
        let nodeOutgoingEdges = get_outgoing_edges(tree, node);

        unset_edges(tree, nodeKey);
        unset_edges(tree, successorKey);
        apply_edges(tree, &successorOutgoingEdges, nodeKey, successorKey);
        apply_edges(tree, &nodeOutgoingEdges, successorKey, nodeKey);

        if (tree.rootNodeKey == nodeKey) {
            tree.rootNodeKey = successorKey;
        };

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
        assert!(*first_value_at(&tree, 8) == 10, 0);
        assert!(*first_value_at(&tree, 10) == 100, 0);
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
        assert!(*first_value_at(&tree, 10) == 100, 0);
        assert!(*first_value_at(&tree, 8) == 10, 0);
        assert!(*first_value_at(&tree, 6) == 1, 0);
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
        assert!(*first_value_at(&tree, 10) == 100, 0);
        assert!(*first_value_at(&tree, 12) == 1000, 0);
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
        assert!(*first_value_at(&tree, 10) == 100, 0);
        assert!(*first_value_at(&tree, 12) == 1000, 0);
        assert!(*first_value_at(&tree, 14) == 10000, 0);
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
    fun test_delete_leaf_black_node_red_leaf_node(signer: signer) {
        //         10B
        //       /    \
        //      3B     15B
        //     /  \    /  \
        //    2B  5B  13B 18B
        //       /
        //      4R
        //

        // Node is red leaf node.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 5: [], 4(R) 5 _ _: [], 5(B) 3 4 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ _: []");
        assert_red_black_tree(&tree);
        delete(&mut tree, 4);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_0(signer: signer) {
        //         10B
        //       /    \
        //      3B     15B
        //     /       /  \
        //    2B      13B 18B
        //

        // Black node with no siblings.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ _: []");
        assert_red_black_tree(&tree);
        delete(&mut tree, 2);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_1(signer: signer) {
        //         10B
        //       /    \
        //      3B     15B
        //     / \     / \
        //    2B 6R  13B 18B
        //       /
        //      4B
        //

        // Sibling is red.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 6: [], 4(B) 6 _ _: [], 6(R) 3 4 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ _: []");
        assert_red_black_tree(&tree);
        delete(&mut tree, 2);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_2(signer: signer) {
        //        10B
        //       /  \
        //      3B   15B
        //     / \   / \
        //    2B 5B 13B 18B

        // Sibling is black and has black children.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 5: [], 5(B) 3 _ _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ _: []");
        delete(&mut tree, 2);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_3(signer: signer) {
        //         10B
        //       /    \
        //      3B     15B
        //     /  \    /  \
        //    2B  5B  13B 18B
        //       /
        //      4R
        //

        // Sibling is black and sibling's closest child is red.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 5: [], 4(R) 5 _ _: [], 5(B) 3 4 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ _: []");
        assert_red_black_tree(&tree);
        delete(&mut tree, 2);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    fun test_delete_leaf_black_node_case_4(signer: signer) {
        //        10B
        //       /   \
        //      3B    15B
        //     / \    / \
        //    2B  6B 13B 18B
        //                 \
        //                  20R
        //

        // Sibling is black and sibling's closest child is black.
        let tree = parse_tree(b"2(B) 3 _ _: [], 3(B) 10 2 6: [], 6(B) 3 _ _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(B) 10 13 18: [], 18(B) 15 _ 20: [], 20(R) 18 _ _: []");
        assert_red_black_tree(&tree);
        delete(&mut tree, 13);
        assert_red_black_tree(&tree);
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
    fun is_red<V: store + drop>(tree: &Tree<V>, nodeKey: u128): bool {
        assert!(!is_empty(tree), TREE_IS_EMPTY);
        assert!(table::contains(&tree.nodes, nodeKey), NODE_NOT_FOUND);
        get_node(tree, nodeKey).isRed
    }

    #[test_only]
    fun right_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_right_child(tree, nodeKey), INVALID_KEY_ACCESS);
        get_node(tree, nodeKey).rightChildNodeKey
    }

    #[test_only]
    fun left_child_key<V: store + drop>(tree: &Tree<V>, nodeKey: u128): u128 {
        assert!(has_left_child(tree, nodeKey), INVALID_KEY_ACCESS);
        get_node(tree, nodeKey).leftChildNodeKey
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

        let nodeKeys = vector::empty<u128>();

        let i = 0;
        while (i < string::length(&str)) {
            let (node, newPos) = parse_node(strRaw, i);
            let nodeKey = node.key;
            if (!node.parentNodeKeyIsSet) {
                tree.rootNodeKey = node.key;
            };
            table::add(&mut tree.nodes, node.key, node);
            tree.keyCount = tree.keyCount + 1;

            vector::push_back(&mut nodeKeys, nodeKey);

            i = newPos;
        };
        i = 0;
        while (i < vector::length(&nodeKeys)) {
            let node = table::borrow(&tree.nodes, *vector::borrow(&nodeKeys, i));
            if (node.parentNodeKeyIsSet) {
                assert!(table::contains(&tree.nodes, node.parentNodeKey), 0);
                let parent = table::borrow(&tree.nodes, node.parentNodeKey);
                let leftChild = parent.leftChildNodeKeyIsSet && parent.leftChildNodeKey == node.key;
                let rightChild = parent.rightChildNodeKeyIsSet && parent.rightChildNodeKey == node.key;
                assert!(leftChild || rightChild, 0);
            };

            if (node.leftChildNodeKeyIsSet) {
                assert!(table::contains(&tree.nodes, node.leftChildNodeKey), 0);
                let leftChild = table::borrow(&tree.nodes, node.leftChildNodeKey);
                assert!(leftChild.parentNodeKeyIsSet && leftChild.parentNodeKey == node.key, 0);
            };

            if (node.rightChildNodeKeyIsSet) {
                assert!(table::contains(&tree.nodes, node.rightChildNodeKey), 0);
                let rightChild = table::borrow(&tree.nodes, node.rightChildNodeKey);
                assert!(rightChild.parentNodeKeyIsSet && rightChild.parentNodeKey == node.key, 0);
            };

            i = i + 1;
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

    #[test(signer = @0x345)]
    fun test_parse_tree_2(signer: &signer) {
        let tree = parse_tree(b"1(R) 3 _ _: [], 3(B) 10 1 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(R) 10 13 _: []");
        assert_inorder_tree(&tree, b"1(R) 3 _ _: [], 3(B) 10 1 _: [], 10(B) root 3 15: [], 13(B) 15 _ _: [], 15(R) 10 13 _: []");
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
        mark_color(&mut tree, 10, true);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 2)]
    fun test_assert_red_black_tree_with_two_adjacent_red_nodes(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35]);
        mark_color(&mut tree, 25, true);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_assert_red_black_tree_with_invalid_black_depth(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35, 40, 45]);
        mark_color(&mut tree, 45, false);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }

    #[test(signer = @0x345)]
    #[expected_failure(abort_code = 3)]
    fun test_assert_red_black_tree_with_invalid_black_depth_leaf_node(signer: signer) {
        let tree = test_tree(vector<u128>[10, 5, 15, 25, 35]);
        mark_color(&mut tree, 35, false);
        assert_red_black_tree(&tree);
        move_to(&signer, tree)
    }
}
