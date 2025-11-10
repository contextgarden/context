/*
    See license.txt in the root of this project.
*/

# if (rpipico)

int signal_buzzer_initialize()
{
    if (0) {
        gpio_init(20);
        gpio_set_dir(20, GPIO_OUT);
        gpio_put(20, 1);
        delay(2000);
        gpio_put(20, 0);
    }
    return 0;
}

int signal_buzzer_done(int what)
{
    return 0;
}

# else 

int signal_buzzer_initialize()
{
    return 0;
}

int signal_buzzer_done(int what)
{
    return 0;
}

# endif 