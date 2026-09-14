class Stopt < Formula
  desc "Library for stochastic optimization by dynamic programming and SDDP"
  homepage "https://gitlab.com/stochastic-control/StOpt"
  url "https://gitlab.com/stochastic-control/StOpt/-/archive/v7.1/StOpt-v7.1.tar.gz"
  sha256 "8bee8f2aab097c91a791729cde34f50b062208a1ab1af4d62ee41dba24a9e5e7"
  license "LGPL-3.0-only"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "boost-mpi"
  depends_on "eigen"
  depends_on "open-mpi"

  uses_from_macos "bzip2"
  uses_from_macos "zlib"

  def install
    # the geners serialization library travels inside StOpt and is built with
    # it; the SDDP and DP CUTS switches build tests, not the library, and the
    # MPI one defines USE_MPI, which the parallel entry points need. libStOpt
    # reaches libgeners through @rpath, so the directory of the library has
    # to be written into it, or nothing that links StOpt can be loaded
    args = %W[
      -DBUILD_PYTHON=OFF
      -DBUILD_TEST=OFF
      -DBUILD_SDDP=OFF
      -DBUILD_DPCUTS=OFF
      -DBUILD_MPI=ON
      -DBUILD_SYSTEM_INSTALL=ON
      -DCMAKE_INSTALL_RPATH=#{loader_path}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cpp").write <<~CPP
      #include <StOpt/sddp/SDDPACut.h>
      int main() { StOpt::SDDPACut cut; return 0; }
    CPP
    system ENV.cxx, "-std=c++17", "test.cpp", "-o", "test",
           "-I#{include}", "-I#{formula_opt_include("eigen")}/eigen3",
           "-I#{formula_opt_include("boost")}",
           "-L#{lib}", "-lStOpt"
    system "./test"
  end
end
