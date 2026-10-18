class Qpoases < Formula
  desc "Online active-set solver for convex quadratic programs"
  homepage "https://github.com/coin-or/qpOASES"
  url "https://github.com/coin-or/qpOASES/archive/refs/tags/releases/3.2.2.tar.gz"
  sha256 "e36d795a17b067ea333793d96f17a14fb2bfbd92a4ab86c7f6f513cd9e3e640d"
  license "LGPL-2.1-or-later"

  depends_on "cmake" => :build

  # a shared library whose own BLAS and LAPACK replacements are renamed, so
  # that it can be linked next to the real ones; the CMake of the project
  # asks for a version that CMake 4 no longer accepts
  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args,
           "-DBUILD_SHARED_LIBS=ON",
           "-DQPOASES_BUILD_EXAMPLES=OFF",
           "-DQPOASES_AVOID_LA_NAMING_CONFLICTS=ON",
           "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"qp.cpp").write <<~CPP
      #include <qpOASES.hpp>
      #include <cstdio>
      USING_NAMESPACE_QPOASES
      int main() {
        // min 0.5 x'x - x1 - x2 s.t. -1 <= x <= 1 and x1 + x2 <= 1
        real_t H[4] = {1, 0, 0, 1}, g[2] = {-1, -1}, A[2] = {1, 1};
        real_t lb[2] = {-1, -1}, ub[2] = {1, 1}, lbA[1] = {-1e20}, ubA[1] = {1};
        QProblem qp(2, 1);
        Options o;
        o.printLevel = PL_NONE;
        qp.setOptions(o);
        int_t nWSR = 10;
        returnValue r = qp.init(H, g, A, lb, ub, lbA, ubA, nWSR);
        real_t x[2];
        qp.getPrimalSolution(x);
        std::printf("%d %g %g\\n", int(r), x[0], x[1]);
        return r == SUCCESSFUL_RETURN ? 0 : 1;
      }
    CPP
    system ENV.cxx, "qp.cpp", "-std=c++11", "-I#{include}", "-L#{lib}",
           "-lqpOASES", "-o", "qp"
    assert_equal "0 0.5 0.5", shell_output("./qp").strip
  end
end
