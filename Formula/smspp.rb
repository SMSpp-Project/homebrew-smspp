class Smspp < Formula
  desc "Framework to model and solve block-structured optimization problems"
  homepage "https://smspp.gitlab.io/"
  url "https://gitlab.com/api/v4/projects/smspp%2Fsmspp-project/packages/generic/smspp-project/0.6.0/smspp-project-0.6.0.tar.gz"
  sha256 "449e4bd652ec89370450a80505a8380551d9d90b4fbd87dbcb6d7a60a4ee2a1f"
  license "LGPL-3.0-only"

  depends_on "cmake" => :build
  depends_on "help2man" => :build
  depends_on "pkgconf" => :build
  depends_on "boost"
  depends_on "clp"
  depends_on "coinutils"
  depends_on "eigen"
  depends_on "highs"
  depends_on "liblinear"
  depends_on "libsvm"
  depends_on "netcdf-cxx"
  depends_on "open-mpi"
  depends_on "openblas"
  depends_on "osi"
  depends_on "smspp/smspp/stopt"

  # the core fetches FastFlow at configure time, which a formula must not do:
  # it is given here instead, at the commit the other packages of the project
  # pin too
  resource "fastflow" do
    url "https://github.com/fastflow/fastflow/archive/d476f66ab924d8d122f54b4b90aee00ef979aea8.tar.gz"
    sha256 "fca23ce672fe12fe7cdbfa6955a982d6eb75816a00d2d97a93deba9b351f9c53"
  end

  def install
    (buildpath/"fastflow").install resource("fastflow")

    # CPLEX, Gurobi and SCIP are not redistributable, so the MILP Solvers come
    # with the HiGHS backend alone; MCFLemonSolver needs the LEMON graph
    # library, which homebrew-core does not carry
    args = %W[
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_tests=OFF
      -DBUILD_MCFLemonSolver=OFF
      -DFETCHCONTENT_SOURCE_DIR_FASTFLOW=#{buildpath}/fastflow
      -DFETCHCONTENT_FULLY_DISCONNECTED=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_CPLEX=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_GUROBI=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_SCIP=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_PIPS=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_Torch=ON
      -DHiGHS_ROOT=#{formula_opt_prefix("highs")}
      -DStOpt_ROOT=#{formula_opt_prefix("stopt")}
      -DCoinUtils_ROOT=#{formula_opt_prefix("coinutils")}
      -DOsi_ROOT=#{formula_opt_prefix("osi")}
      -DClp_ROOT=#{formula_opt_prefix("clp")}
    ]

    # the umbrella forces shared libraries and a package registry of its own
    rm "CMakeSettings.txt"

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # every tool finds its configuration files next to the executable, and the
    # examples of the tools are installed with them
    examples = share/"SMS++_tools"
    mcf = shell_output("#{bin}/mcfblock_solver #{examples}/mcfblock_solver/examples/example.dmx")
    assert_match "Upper bound = 1.40000000e+01", mcf
    bkb = shell_output("#{bin}/bkblock_solver #{examples}/bkblock_solver/examples/example.txt")
    assert_match "Upper bound = 1.50000000e+01", bkb
    system bin/"ucblock_solver", "--version"
    system bin/"block_solver", "--help"

    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 3.21)
      project(consumer LANGUAGES CXX)
      find_package(SMS++ REQUIRED)
      find_package(UCBlock REQUIRED)
      add_executable(consumer consumer.cpp)
      target_link_libraries(consumer PRIVATE SMS++::SMS++ SMS++::UCBlock)
    CMAKE
    (testpath/"consumer.cpp").write <<~CPP
      #include <UCBlock.h>
      int main() { auto b = SMSpp_di_unipi_it::Block::new_Block( "UCBlock" ); return b ? 0 : 1; }
    CPP
    system "cmake", "-S", testpath, "-B", testpath/"build",
           "-DCMAKE_PREFIX_PATH=#{prefix}"
    system "cmake", "--build", testpath/"build"
    system testpath/"build/consumer"
  end
end
