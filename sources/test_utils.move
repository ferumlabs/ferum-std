module ferum_std::test_utils {
    use std::string::{Self, String};
    use std::vector;

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

    public fun u128_from_string(str: &String): u128 {
        let i = 0;
        let num = 0;
        while (i < string::length(str)) {
            num = num * 10;
            let sub = string::sub_string(str, i, i + 1);
            num = num + charToNum(*string::bytes(&sub));
            i = i + 1;
        };
        num
    }

    fun charToNum(s: vector<u8>): u128 {
        assert!(vector::length(&s) == 1, 0);
        if (s == b"9") {
            return 9
        };
        if (s == b"8") {
            return 8
        };
        if (s == b"7") {
            return 7
        };
        if (s == b"6") {
            return 6
        };
        if (s == b"5") {
            return 5
        };
        if (s == b"4") {
            return 4
        };
        if (s == b"3") {
            return 3
        };
        if (s == b"2") {
            return 2
        };
        if (s == b"1") {
            return 1
        };
        if (s == b"0") {
            return 0
        };

        assert!(false, 0);
        0
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