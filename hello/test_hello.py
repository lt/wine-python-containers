import unittest
import sys
import os

sys.path.append(os.getcwd())

import hello

class TestHello(unittest.TestCase):
    def test_load(self):
        result = hello.load()
        self.assertTrue(isinstance(result, dict))
        self.assertEqual(result.get("name"), "hello_module")
        self.assertEqual(result.get("version"), "1.0.0")

if __name__ == "__main__":
    unittest.main()
