cmake_minimum_required(VERSION 3.20)
project(apibattle_api CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Drogon CONFIG REQUIRED)

# Embed the OpenAPI spec in the binary; re-run configure when it changes.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS openapi.yaml)
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/openapi.yaml OPENAPI_SPEC)
configure_file(src/openapi_spec.h.in ${CMAKE_CURRENT_BINARY_DIR}/generated/openapi_spec.h @ONLY)

add_executable(apibattle_api
    src/main.cc
    src/controllers/AccountController.cc
    src/controllers/TransactionController.cc
    src/controllers/DocsController.cc
)
target_include_directories(apibattle_api PRIVATE src ${CMAKE_CURRENT_BINARY_DIR}/generated)
target_link_libraries(apibattle_api PRIVATE Drogon::Drogon)
