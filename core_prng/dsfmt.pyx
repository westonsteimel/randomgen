import operator
from libc.stdlib cimport malloc, free
from cpython.pycapsule cimport PyCapsule_New

import numpy as np
cimport numpy as np

from common cimport *
from core_prng.entropy import random_entropy
import core_prng.pickle
cimport entropy

np.import_array()

DEF DSFMT_MEXP = 19937
DEF DSFMT_N = 191 # ((DSFMT_MEXP - 128) / 104 + 1)
DEF DSFMT_N_PLUS_1 = 192 # DSFMT_N + 1
DEF DSFMT_N64 = DSFMT_N * 2

cdef extern from "src/dsfmt/dSFMT.h":

    union W128_T:
        uint64_t u[2];
        uint32_t u32[4];
        double d[2];

    ctypedef W128_T w128_t;

    struct DSFMT_T:
        w128_t status[DSFMT_N_PLUS_1];
        int idx;

    ctypedef DSFMT_T dsfmt_t;

    struct s_dsfmt_state:
        dsfmt_t *state
        int has_uint32
        uint32_t uinteger

        double *buffered_uniforms
        int buffer_loc

    ctypedef s_dsfmt_state dsfmt_state

    double dsfmt_next_double(dsfmt_state *state)  nogil
    uint64_t dsfmt_next64(dsfmt_state *state)  nogil
    uint64_t dsfmt_next32(dsfmt_state *state)  nogil

    void dsfmt_init_gen_rand(dsfmt_t *dsfmt, uint32_t seed)
    void dsfmt_init_by_array(dsfmt_t *dsfmt, uint32_t init_key[], int key_length)
    # void dsfmt_jump(dsfmt_state  *state)

cdef uint64_t dsfmt_uint64(void* st):# nogil:
    return dsfmt_next64(<dsfmt_state *>st)

cdef uint32_t dsfmt_uint32(void *st) nogil:
    return dsfmt_next32(<dsfmt_state *> st)

cdef double dsfmt_double(void* st) nogil:
    return dsfmt_next_double(<dsfmt_state *>st)

cdef class DSFMT:
    """
    Prototype Core PRNG using dsfmt

    Parameters
    ----------
    seed : int, array of int
        Integer or array of integers between 0 and 2**64 - 1

    Notes
    -----
    Exposes no user-facing API except `state`. Designed for use in a
    `RandomGenerator` object.
    """
    cdef dsfmt_state  *rng_state
    cdef prng_t *_prng
    cdef public object _prng_capsule

    def __init__(self, seed=None):
        self.rng_state = <dsfmt_state *>malloc(sizeof(dsfmt_state))
        self.rng_state.state = <dsfmt_t *>malloc(sizeof(dsfmt_t))
        self.rng_state.buffered_uniforms = <double *>malloc(DSFMT_N64 * sizeof(double))
        self.rng_state.buffer_loc = DSFMT_N64
        self._prng = <prng_t *>malloc(sizeof(prng_t))
        self._prng.binomial = <binomial_t *>malloc(sizeof(binomial_t))
        self.seed(seed)
        self._prng.state = <void *>self.rng_state
        self._prng.next_uint64 = &dsfmt_uint64
        self._prng.next_uint32 = &dsfmt_uint32
        self._prng.next_double = &dsfmt_double
        cdef const char *name = "CorePRNG"
        self._prng_capsule = PyCapsule_New(<void *>self._prng, name, NULL)

    # Pickling support:
    def __getstate__(self):
        return self.state

    def __setstate__(self, state):
        self.state = state

    def __reduce__(self):
        return (core_prng.pickle.__prng_ctor,
                (self.state['prng'],),
                self.state)

    def __dealloc__(self):
        free(self.rng_state.state)
        free(self.rng_state.buffered_uniforms)
        free(self.rng_state)
        free(self._prng.binomial)
        free(self._prng)

    def _reset_state_variables(self):
        pass

    def __random_integer(self, bits=64):
        """
        64-bit Random Integers from the PRNG

        Parameters
        ----------
        bits : {32, 64}
            Number of random bits to return

        Returns
        -------
        rv : int
            Next random value

        Notes
        -----
        Testing only
        """
        if bits == 64:
            return dsfmt_next64(self.rng_state)
        elif bits == 32:
            return dsfmt_next32(self.rng_state)
        else:
            raise ValueError('bits must be 32 or 64')

    def _benchmark(self, Py_ssize_t cnt):
        cdef Py_ssize_t i
        for i in range(cnt):
            self._prng.next_uint64(self._prng.state)


    def seed(self, seed=None):
        """
        seed(seed=None, stream=None)

        Seed the generator.

        This method is called when ``RandomState`` is initialized. It can be
        called again to re-seed the generator. For details, see
        ``RandomState``.

        Parameters
        ----------
        seed : int, optional
            Seed for ``RandomState``.

        Raises
        ------
        ValueError
            If seed values are out of range for the PRNG.
        """
        cdef np.ndarray obj
        try:
            if seed is None:
                try:
                    seed = random_entropy(1)
                except RuntimeError:
                    seed = random_entropy(1, 'fallback')
                dsfmt_init_gen_rand(self.rng_state.state, seed)
            else:
                if hasattr(seed, 'squeeze'):
                    seed = seed.squeeze()
                idx = operator.index(seed)
                if idx > int(2**32 - 1) or idx < 0:
                    raise ValueError("Seed must be between 0 and 2**32 - 1")
                dsfmt_init_gen_rand(self.rng_state.state, seed)
        except TypeError:
            obj = np.asarray(seed).astype(np.int64, casting='safe').ravel()
            if ((obj > int(2**32 - 1)) | (obj < 0)).any():
                raise ValueError("Seed must be between 0 and 2**32 - 1")
            obj = obj.astype(np.uint32, casting='unsafe', order='C')
            dsfmt_init_by_array(self.rng_state.state,
                                <uint32_t *>obj.data,
                                np.PyArray_DIM(obj, 0))

    def seed(self, seed=None):
        """
        seed(seed=None, stream=None)

        Seed the generator.

        This method is called when ``RandomState`` is initialized. It can be
        called again to re-seed the generator. For details, see
        ``RandomState``.

        Parameters
        ----------
        seed : int, optional
            Seed for ``RandomState``.

        Raises
        ------
        ValueError
            If seed values are out of range for the PRNG.

        """
        cdef np.ndarray init_key
        ub =  2 ** 32
        if seed is None:
            try:
                state = random_entropy(1)
            except RuntimeError:
                state = random_entropy(1, 'fallback')
            seed = state[0]
        if np.isscalar(seed):
            # TODO: This isn't correct, but works now
            seed = int(seed)
            if seed < 0 or seed > ub:
                raise ValueError('seed must be an unsigned 32-bit integer')
            dsfmt_init_gen_rand(self.rng_state.state, seed)
        else:
            # TODO: This also need to be impeoved to be more careful
            init_key = np.asarray(seed, dtype=np.uint32).ravel()
            dsfmt_init_by_array(self.rng_state.state,
                                <uint32_t *>init_key.data,
                                init_key.shape[0])

        self._reset_state_variables()

#    def jump(self):
#        dsfmt_jump(self.rng_state)
#        return self

    @property
    def state(self):
        """Get or set the PRNG state"""
        cdef Py_ssize_t i, j, loc = 0
        cdef uint64_t[::1] state
        cdef double[::1] buffered_uniforms

        state = np.empty(2 *DSFMT_N_PLUS_1, dtype=np.uint64)
        for i in range(DSFMT_N_PLUS_1):
            for j in range(2):
                state[loc] = self.rng_state.state.status[i].u[j]
                loc += 1
        buffered_uniforms = np.empty(DSFMT_N64,dtype=np.double)
        for i in range(DSFMT_N64):
            buffered_uniforms[i] = self.rng_state.buffered_uniforms[i]
        return {'prng': self.__class__.__name__,
                'state': {'state':np.asarray(state),
                          'idx':self.rng_state.state.idx},
                'buffer_loc': self.rng_state.buffer_loc,
                'buffered_uniforms':np.asarray(buffered_uniforms)}

    @state.setter
    def state(self, value):
        cdef Py_ssize_t i, j, loc = 0
        if not isinstance(value, dict):
            raise TypeError('state must be a dict')
        prng = value.get('prng', '')
        if prng != self.__class__.__name__:
            raise ValueError('state must be for a {0} '
                             'PRNG'.format(self.__class__.__name__))
        state = value['state']['state']
        for i in range(DSFMT_N_PLUS_1):
            for j in range(2):
                self.rng_state.state.status[i].u[j] = state[loc]
                loc += 1
        self.rng_state.state.idx = value['state']['idx']
        buffered_uniforms = value['buffered_uniforms']
        for i in range(DSFMT_N64):
            self.rng_state.buffered_uniforms[i] = buffered_uniforms[i]
        self.rng_state.buffer_loc = value['buffer_loc']