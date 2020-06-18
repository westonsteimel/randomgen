import os
import sys

from randomgen.aes import AESCounter
from randomgen.chacha import ChaCha
from randomgen.dsfmt import DSFMT
from randomgen.entropy import random_entropy
from randomgen.generator import ExtendedGenerator, Generator
from randomgen.hc128 import HC128
from randomgen.jsf import JSF
from randomgen.lxm import LXM
from randomgen.mt64 import MT64
from randomgen.mt19937 import MT19937
from randomgen.mtrand import RandomState
from randomgen.pcg32 import PCG32
from randomgen.pcg64 import PCG64, LCG128Mix
from randomgen.philox import Philox
from randomgen.rdrand import RDRAND
from randomgen.seed_sequence import SeedlessSeedSequence, SeedSequence
from randomgen.sfc import SFC64
from randomgen.sfmt import SFMT
from randomgen.speck128 import SPECK128
from randomgen.threefry import ThreeFry
from randomgen.wrapper import UserBitGenerator
from randomgen.xoroshiro128 import Xoroshiro128
from randomgen.xorshift1024 import Xorshift1024
from randomgen.xoshiro256 import Xoshiro256
from randomgen.xoshiro512 import Xoshiro512

from ._version import get_versions

PKG = os.path.dirname(__file__)


__all__ = [
    "AESCounter",
    "ChaCha",
    "LCG128Mix",
    "DSFMT",
    "ExtendedGenerator",
    "Generator",
    "HC128",
    "JSF",
    "LXM",
    "MT19937",
    "MT64",
    "PCG32",
    "PCG64",
    "Philox",
    "RDRAND",
    "RandomState",
    "SFC64",
    "SFMT",
    "SPECK128",
    "SeedSequence",
    "SeedlessSeedSequence",
    "ThreeFry",
    "UserBitGenerator",
    "Xoroshiro128",
    "Xorshift1024",
    "Xoshiro256",
    "Xoshiro512",
    "random_entropy",
]

__version__ = get_versions()["version"]
del get_versions


def test(extra_args=None):
    try:
        import pytest
    except ImportError as err:
        raise ImportError("Need pytest>=5.0.1 to run tests") from err
    cmd = ["--skip-slow"]
    if extra_args:
        if not isinstance(extra_args, list):
            extra_args = [extra_args]
        cmd = extra_args
    cmd += [PKG]
    joined = " ".join(cmd)
    print(f"running: pytest {joined}")
    sys.exit(pytest.main(cmd))
