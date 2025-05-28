#include "sail.h"
#include "sail_config.h"
#include "rts.h"
#include "elf.h"
#ifdef __cplusplus
extern "C" {
#endif
void (*sail_rts_set_coverage_file)(const char *) = NULL;

// union exception
enum kind_zexception { Kind_zException };

struct zexception {
  enum kind_zexception kind;
  union {struct { unit zException; };} variants;
};

static void CREATE(zexception)(struct zexception *op) {
  op->kind = Kind_zException;
}

static void RECREATE(zexception)(struct zexception *op) {

}

static void KILL(zexception)(struct zexception *op) {
  {}
}

static void COPY(zexception)(struct zexception *rop, struct zexception op) {
  {};
  rop->kind = op.kind;
  if (op.kind == Kind_zException) {
    rop->variants.zException = op.variants.zException;
  }
}

static bool EQUAL(zexception)(struct zexception op1, struct zexception op2) {
  if (op1.kind == Kind_zException && op2.kind == Kind_zException) {
    return EQUAL(unit)(op1.variants.zException, op2.variants.zException);
  } else return false;
}

static void zException(struct zexception *rop, unit op) {
  {}
  rop->kind = Kind_zException;
  rop->variants.zException = op;
}

struct zexception *current_exception = NULL;

bool have_exception = false;

sail_string *throw_location = NULL;

unit zmain(unit);

unit zmain(unit z3zE0)
{
  __label__ end_function_1, end_block_exception_2;

  unit z8zE0;
  bool z2zE2;
  {
    int64_t z2zE1;
    {
      uint64_t z2zE0;
      {
        lbits z3zE4;
        CREATE(lbits)(&z3zE4);
        CONVERT_OF(lbits, fbits)(&z3zE4, UINT64_C(0x0), UINT64_C(4) , true);
        sail_int z3zE5;
        CREATE(sail_int)(&z3zE5);
        CONVERT_OF(sail_int, mach_int)(&z3zE5, INT64_C(32));
        lbits z3zE6;
        CREATE(lbits)(&z3zE6);
        zero_extend(&z3zE6, z3zE4, z3zE5);
        z2zE0 = CONVERT_OF(fbits, lbits)(z3zE6, true);
        KILL(lbits)(&z3zE6);
        KILL(sail_int)(&z3zE5);
        KILL(lbits)(&z3zE4);
      }
      {
        lbits z3zE2;
        CREATE(lbits)(&z3zE2);
        CONVERT_OF(lbits, fbits)(&z3zE2, z2zE0, UINT64_C(32) , true);
        sail_int z3zE3;
        CREATE(sail_int)(&z3zE3);
        sail_signed(&z3zE3, z3zE2);
        z2zE1 = CONVERT_OF(mach_int, sail_int)(z3zE3);
        KILL(sail_int)(&z3zE3);
        KILL(lbits)(&z3zE2);
      }
    }
    {
      sail_int z3zE7;
      CREATE(sail_int)(&z3zE7);
      CONVERT_OF(sail_int, mach_int)(&z3zE7, z2zE1);
      sail_int z3zE8;
      CREATE(sail_int)(&z3zE8);
      CONVERT_OF(sail_int, mach_int)(&z3zE8, INT64_C(0));
      z2zE2 = eq_int(z3zE7, z3zE8);
      KILL(sail_int)(&z3zE8);
      KILL(sail_int)(&z3zE7);
    }
  }
  z8zE0 = sail_assert(z2zE2, "./test/builtins/test.sail:7.47-7.48");
end_function_1: ;
  return z8zE0;
end_block_exception_2: ;

  return UNIT;
}

unit zinitializze_registers(unit);

unit zinitializze_registers(unit z3zE1)
{
  __label__ end_function_4, end_block_exception_5;

  unit z8zE1;
  z8zE1 = UNIT;
end_function_4: ;
  return z8zE1;
end_block_exception_5: ;

  return UNIT;
}



void model_init(void)
{
  setup_rts();
  current_exception = sail_new(struct zexception);
  CREATE(zexception)(current_exception);
  throw_location = sail_new(sail_string);
  CREATE(sail_string)(throw_location);
}

void model_fini(void)
{
  cleanup_rts();
  if (have_exception) {fprintf(stderr, "Exiting due to uncaught exception: %s\n", *throw_location);}
  KILL(zexception)(current_exception);
  sail_free(current_exception);
  KILL(sail_string)(throw_location);
  sail_free(throw_location);
  if (have_exception) {exit(EXIT_FAILURE);}
}

void model_pre_exit()
{
}

int model_main(int argc, char *argv[])
{
  model_init();
  if (process_arguments(argc, argv)) exit(EXIT_FAILURE);
  zmain(UNIT);
  model_fini();
  model_pre_exit();
  return EXIT_SUCCESS;
}

const size_t SAIL_TEST_COUNT = 0;
unit (*const SAIL_TESTS[1])(unit) = {
  NULL
};
const char* const SAIL_TEST_NAMES[1] = {
  NULL
};

void model_test(void)
{
  for (size_t i = 0; i < SAIL_TEST_COUNT; ++i) {
    model_init();
    printf("Testing %s\n", SAIL_TEST_NAMES[i]);
    SAIL_TESTS[i](UNIT);
    printf("Pass\n");
    model_fini();
  }
}

int main(int argc, char *argv[])
{
  int retcode;
  retcode = model_main(argc, argv);
  return retcode;
}

#ifdef __cplusplus
}
#endif
