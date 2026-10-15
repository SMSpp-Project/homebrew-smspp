class Daqp < Formula
  desc "Dual active-set solver for convex quadratic programs"
  homepage "https://github.com/darnstrom/daqp"
  url "https://github.com/darnstrom/daqp/archive/refs/tags/v0.10.3.tar.gz"
  sha256 "6105b9875100214786fce5caf2829380c3e49981757fede84e42b0008a210949"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/smspp-project/smspp"
    sha256 cellar: :any, arm64_sequoia: "400dc9892b4b69ef544a9164dc9b97ef9ec9f3c3f0c6c27cae7d44e1cc7ef055"
    sha256 cellar: :any, x86_64_linux:  "c084a16ed395e64d5e74ffb744a040bcf912d16651edeffabc81d519657e57a8"
  end

  depends_on "cmake" => :build

  # the static library links the shared one, the shared one does not declare
  # the math library it uses, and the CMake configuration goes to
  # <prefix>/cmake, where find_package() does not look: the patch is the one
  # of the vcpkg port and of the Debian package of the project
  patch :DATA

  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args,
           "-DDAQP_CMAKE_INSTALL_DIR=lib/cmake/daqp"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"qp.c").write <<~C
      #include <daqp/api.h>
      #include <stdio.h>
      int main(void) {
        /* min 0.5 x'x - x1 - x2 s.t. -1 <= x <= 1 and x1 + x2 <= 1 */
        c_float H[4] = {1, 0, 0, 1}, f[2] = {-1, -1};
        c_float A[2] = {1, 1}, bupper[3] = {1, 1, 1}, blower[3] = {-1, -1, -1e30};
        int sense[3] = {0, 0, 0};
        DAQPProblem qp = {2, 3, 2, H, f, A, bupper, blower, sense};
        c_float x[2], lam[3];
        DAQPResult res;
        res.x = x;
        res.lam = lam;
        daqp_quadprog(&res, &qp, NULL);
        printf("%d %g %g\\n", res.exitflag, x[0], x[1]);
        return res.exitflag == 1 ? 0 : 1;
      }
    C
    system ENV.cc, "qp.c", "-I#{include}", "-L#{lib}", "-ldaqp", "-o", "qp"
    assert_equal "1 0.5 0.5", shell_output("./qp").strip

    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 3.10)
      project(qp C)
      find_package(daqp CONFIG REQUIRED)
      add_executable(qp-cmake qp.c)
      target_link_libraries(qp-cmake PRIVATE daqp)
    CMAKE
    system "cmake", "-S", testpath, "-B", testpath/"build",
           "-DCMAKE_PREFIX_PATH=#{prefix}"
    system "cmake", "--build", testpath/"build"
    assert_equal "1 0.5 0.5", shell_output(testpath/"build/qp-cmake").strip
  end
end

__END__
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -30,7 +30,7 @@
 endif()
 
 option (FASTER_MATH "Enable some faster math" ON)
-if(FASTER_MATH)
+if(FASTER_MATH AND NOT MSVC)
     set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fassociative-math -fno-signed-zeros -fno-trapping-math")
 endif()
 
@@ -69,41 +69,62 @@
 endif()
 
 
+# the two libraries can be built one without the other, and the static one
+# alone takes the name of the library, so that a package carries one of them
+option (DAQP_BUILD_SHARED "Build the shared library daqp" ON)
+option (DAQP_BUILD_STATIC "Build the static library daqpstat" ON)
+set(DAQP_CMAKE_INSTALL_DIR cmake CACHE STRING
+    "Directory where the CMake configuration is installed")
+
+set(daqp_targets "")
+
+if(DAQP_BUILD_STATIC)
 add_library(daqpstat STATIC ${daqp_src} ${daqp_headers} ${daqp_codegen_src} ${daqp_codegen_headers})
 add_library(daqp::daqpstat ALIAS daqpstat)
 target_include_directories(daqpstat PUBLIC
     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
     $<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}>
 )
+if(NOT DAQP_BUILD_SHARED)
+  set_target_properties(daqpstat PROPERTIES OUTPUT_NAME daqp)
+endif()
+list(APPEND daqp_targets daqpstat)
+endif()
 
+if(DAQP_BUILD_SHARED)
 add_library(daqp SHARED ${daqp_src} ${daqp_headers} ${daqp_codegen_src} ${daqp_codegen_headers})
 add_library(daqp::daqp ALIAS daqp)
 set_target_properties(daqp PROPERTIES
   VERSION ${PROJECT_VERSION}
   SOVERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
+  WINDOWS_EXPORT_ALL_SYMBOLS ON
 )
 target_include_directories(daqp PUBLIC
     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
     $<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}>
 )
+list(APPEND daqp_targets daqp)
+endif()
 
-set(CMAKE_C_STANDARD_LIBRARIES "${CMAKE_C_STANDARD_LIBRARIES}") # math for C api
-set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -Wall -Wextra")
+# the math library, which the C library of the system keeps apart
+if(UNIX AND NOT APPLE)
+  foreach(t ${daqp_targets})
+    target_link_libraries(${t} PRIVATE m)
+  endforeach()
+endif()
 
-target_link_libraries(daqpstat daqp)
+if(NOT MSVC)
+  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -Wall -Wextra")
+endif()
 
 # Install
-install(TARGETS daqpstat EXPORT  ${PROJECT_NAME}Config
-  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
-  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
-  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
-install(TARGETS daqp EXPORT  ${PROJECT_NAME}Config
+install(TARGETS ${daqp_targets} EXPORT  ${PROJECT_NAME}Config
   ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
   LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
   RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
 install(FILES ${daqp_headers} ${daqp_codegen_headers} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/daqp")
 
-install(EXPORT ${PROJECT_NAME}Config DESTINATION cmake)
+install(EXPORT ${PROJECT_NAME}Config DESTINATION "${DAQP_CMAKE_INSTALL_DIR}")
 
 if(EIGEN)
   add_subdirectory(interfaces/daqp-eigen)
