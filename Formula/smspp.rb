class Smspp < Formula
  desc "Framework to model and solve block-structured optimization problems"
  homepage "https://smspp.gitlab.io/"
  url "https://gitlab.com/api/v4/projects/smspp%2Fsmspp-project/packages/generic/smspp-project/0.7.0/smspp-project-0.7.0.tar.gz"
  sha256 "66cddca3f77e92d1e7426a7613742efec8492cd84627fa56eedce8b478222d96"
  license "LGPL-3.0-only"

  bottle do
    root_url "https://ghcr.io/v2/smspp-project/smspp"
    sha256 cellar: :any, arm64_sequoia: "7d31cb3e58c270a79e2d047e797239dcff7a2e4b0242435b6813d4a38d278f0c"
    sha256 cellar: :any, x86_64_linux:  "c76a3af5c18b6a68a6acf88d444b6219cfc86450025af073362c0edb7610b366"
  end

  depends_on "cmake" => :build
  depends_on "help2man" => :build
  depends_on "pkgconf" => :build
  depends_on "boost"
  depends_on "boost-mpi"
  depends_on "cadical"
  depends_on "eigen"
  depends_on "highs"
  depends_on "liblinear"
  depends_on "libsvm"
  depends_on "minisat"
  depends_on "netcdf-cxx"
  depends_on "open-mpi"
  depends_on "smspp-project/smspp/daqp"
  depends_on "smspp-project/smspp/stopt"

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
    # with the HiGHS and DAQP backends alone; MCFLemonSolver needs the LEMON
    # graph library, which homebrew-core does not carry
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
      -DDAQP_ROOT=#{formula_opt_prefix("daqp")}
      -DStOpt_ROOT=#{formula_opt_prefix("stopt")}
      -DCADICAL_ROOT=#{formula_opt_prefix("cadical")}
      -DMINISAT_ROOT=#{formula_opt_prefix("minisat")}
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
    mcf = shell_output("#{bin}/smspp_mcfblock_solver #{examples}/mcfblock_solver/examples/example.dmx")
    assert_match "Upper bound = 1.40000000e+01", mcf
    bkb = shell_output("#{bin}/smspp_bkblock_solver #{examples}/bkblock_solver/examples/example.txt")
    assert_match "Upper bound = 1.50000000e+01", bkb
    system bin/"smspp_ucblock_solver", "--version"
    system bin/"smspp_block_solver", "--help"

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
