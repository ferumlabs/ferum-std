module ferum_std::test_utils {
    use std::string::{Self, String};
    use std::vector;

    ///
    /// PUBLIC
    ///

    public fun compare_vector_128(v: &vector<u128>, byteString: vector<u8>): bool {
        *string::bytes(&to_string_vector(v, b", ")) == byteString
    }

    public fun to_string_vector(v: &vector<u128>, separator: vector<u8>): String {
        let index = 0;
        let buffer = &mut string::utf8(b"");
        let separatorSring = string::utf8(separator);
        while (index < vector::length(v)) {
            let element = to_string_u128(*vector::borrow(v, index));
            string::append(buffer, element);
            index = index + 1;
            if (index < vector::length(v)) {
                string::append(buffer, separatorSring);
            };
        };
        *buffer
    }

    public fun to_string_u128(value: u128): String {
        // Copied from movemate
        // https://github.com/pentagonxyz/movemate/blob/main/aptos/sources/to_string.move#L17-L28
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    #[test]
    fun test_compare_vector_with_empty_vector() {
        let v = &mut vector::empty<u128>();
        assert!(compare_vector_128(v, b""), 0)
    }

    #[test]
    fun test_compare_vector_with_one_element() {
        let v = &mut vector::empty<u128>();
        vector::push_back(v, 10);
        assert!(compare_vector_128(v, b"10"), 0)
    }

    #[test]
    fun test_compare_vector_with_several_elements() {
        let v = &mut vector::empty<u128>();
        vector::push_back(v, 10);
        vector::push_back(v, 12);
        vector::push_back(v, 14);
        assert!(compare_vector_128(v, b"10, 12, 14"), 0)
    }
}