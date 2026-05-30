import sys
import unittest
from unittest.mock import MagicMock

sys.modules['src.db'] = MagicMock()
sys.modules['src.db.visit_count'] = MagicMock()

from src.app import app

class TestHealthEndpoint(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_health_status_code(self):
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()
