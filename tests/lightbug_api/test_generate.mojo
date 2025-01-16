from testing import *
from emberjson import JSON, Object, Array
from lightbug_api.openapi.generate import OpenAPIGenerator

def test_create_endpoint():
    var generator = OpenAPIGenerator()

    var function_data = JSON.from_string("""
    {
        "name": "test_function",
        "overloads": [{
            "returnsDoc": "Test response",
            "summary": "Test summary",
            "description": "Test description. Tags: api test",
            "args": [{
                "description": "Test request"
            }]
        }]
    }
    """)
    
    var endpoint = generator.create_endpoint(function_data, "post")
    assert_equal(endpoint["summary"], "test_function endpoint")
    assert_equal(endpoint["operationId"], "test_function")
    assert_equal(endpoint["description"], "Test summary")
    assert_true("requestBody" in endpoint)
    assert_true("responses" in endpoint)
    assert_true("200" in endpoint["responses"][Object])

def test_create_components_schema():
    var generator = OpenAPIGenerator()
    var components = generator.create_components_schema()
    
    assert_true("schemas" in components)
    assert_true("HTTPRequest" in components["schemas"][Object])
    assert_true("HTTPResponse" in components["schemas"][Object])
    
    var http_request = components["schemas"][Object]["HTTPRequest"][Object]
    assert_equal(http_request["type"], "object")
    assert_true("properties" in http_request)
    assert_true("body_raw" in http_request["properties"][Object])
    assert_true("uri" in http_request["properties"][Object])
    assert_true("method" in http_request["properties"][Object])

def test_create_paths():
    var generator = OpenAPIGenerator()
    
    var mojo_doc = JSON.from_string("""
    {
        "decl": {
            "functions": [{
                "name": "test_handler",
                "overloads": [{
                    "returnsDoc": "Test response",
                    "summary": "Test summary"
                }]
            }]
        }
    }
    """)
    
    var router_metadata = JSON.from_string("""
    {
        "routes": [{
            "handler": "test_handler",
            "path": "/test",
            "method": "POST"
        }]
    }
    """)
    
    var paths = generator.create_paths(mojo_doc, router_metadata)
    assert_true("/test" in paths)
    assert_true("post" in paths["/test"][Object])
    assert_equal(paths["/test"][Object]["post"][Object]["summary"], "test_handler endpoint")

def test_generate_spec():
    var generator = OpenAPIGenerator()
    
    var mojo_doc = JSON.from_string("""
    {
        "version": "1.0.0",
        "decl": {
            "name": "Test API",
            "functions": []
        }
    }
    """)
    
    var router_metadata = JSON.from_string("""
    {
        "routes": []
    }
    """)
    
    var spec = generator.generate_spec(mojo_doc, router_metadata)
    assert_equal(spec["openapi"], "3.0.0")
    assert_equal(spec["info"][Object]["title"], "Test API")
    assert_equal(spec["info"][Object]["version"], "1.0.0")
    assert_true("paths" in spec)
    assert_true("components" in spec)

def test_endpoint_tags():
    var generator = OpenAPIGenerator()

    # Test 1: Basic tags extraction
    var function_data = JSON.from_string("""
    {
        "name": "test_function",
        "overloads": [{
            "returnsDoc": "Test response",
            "summary": "Test summary",
            "description": "Some description. Tags: api, test, auth",
            "args": [{
                "description": "Test request"
            }]
        }]
    }
    """)
    
    var endpoint = generator.create_endpoint(function_data, "post")
    
    assert_true("tags" in endpoint)
    var tag_array = endpoint["tags"][Array]
    assert_equal(len(tag_array), 3)
    assert_equal(tag_array[0].__str__(), '"api"')
    assert_equal(tag_array[1].__str__(), '"test"')
    assert_equal(tag_array[2].__str__(), '"auth"')

    # Test 2: Tags with control characters
    var function_data_control_chars = JSON.from_string('''
    {
        "name": "test_function",
        "overloads": [{
            "returnsDoc": "Test response",
            "summary": "Test summary",
            "description": "Some description. Tags:\\n        hello,\\twhat,\\r\\nup",
            "args": [{
                "description": "Test request"
            }]
        }]
    }
    ''')
    
    var endpoint_control_chars = generator.create_endpoint(function_data_control_chars, "post")
    
    assert_true("tags" in endpoint_control_chars)
    var tag_array_control_chars = endpoint_control_chars["tags"][Array]
    assert_equal(len(tag_array_control_chars), 3)
    assert_equal(tag_array_control_chars[0].__str__(), '"hello"')
    assert_equal(tag_array_control_chars[1].__str__(), '"what"')
    assert_equal(tag_array_control_chars[2].__str__(), '"up"')

    # Test 3: Tags with extra whitespace
    var function_data_whitespace = JSON.from_string("""
    {
        "name": "test_function",
        "overloads": [{
            "returnsDoc": "Test response",
            "summary": "Test summary",
            "description": "Some description. Tags:    api   ,    test   ,   auth   ",
            "args": [{
                "description": "Test request"
            }]
        }]
    }
    """)
    
    var endpoint_whitespace = generator.create_endpoint(function_data_whitespace, "post")
    
    assert_true("tags" in endpoint_whitespace)
    var tag_array_whitespace = endpoint_whitespace["tags"][Array]
    assert_equal(len(tag_array_whitespace), 3)
    assert_equal(tag_array_whitespace[0].__str__(), '"api"')
    assert_equal(tag_array_whitespace[1].__str__(), '"test"')
    assert_equal(tag_array_whitespace[2].__str__(), '"auth"')

    # Test 4: No tags
    var function_data_no_tags = JSON.from_string("""
    {
        "name": "test_function",
        "overloads": [{
            "returnsDoc": "Test response",
            "summary": "Test summary",
            "description": "Some description without tags",
            "args": [{
                "description": "Test request"
            }]
        }]
    }
    """)
    
    var endpoint_no_tags = generator.create_endpoint(function_data_no_tags, "post")
    assert_false("tags" in endpoint_no_tags)
