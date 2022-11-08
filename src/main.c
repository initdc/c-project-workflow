#include <stdio.h>
#include "../lib/hello.h"
#include "../lib/world.h"

int main()
{
    printf("%s%s\n", hello(), world());
    return 0;
}
