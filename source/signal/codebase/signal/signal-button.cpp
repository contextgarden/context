/*
    See license.txt in the root of this project.
*/

// needs volatile variables 

// void signal_button_handler(uint gpio, uint32_t events) {
//     signal_leds_all(signal_currentstatus.colors.black, 1);
// }
//
// gpio_set_irq_enabled_with_callback(PIO_USEDBUTTONPIN, GPIO_IRQ_EDGE_RISE | GPIO_IRQ_EDGE_FALL, true, &signal_button_handler);
// void gpio_output_set(uint32 set_mask,uint32 clear_mask,uint32 enable_mask,uint32 disable_mask);

# include <signal-common.h>
# include <signal-button.h>
# include <signal-wifi.h>

# if SIGNAL_USE_BUTTONS

    # define PIO_USEDBUTTONPIN_LEFT  5
    # define PIO_USEDBUTTONPIN_RIGHT 6

    # if (defined(PICO_RP2040) || defined(PICO_RP2350))

        static int signal_pin_initialize(int pin) 
        {
            gpio_init(pin); /* to ground */
            gpio_set_dir(pin, GPIO_IN);
            gpio_pull_up(pin);
            return 1;
        }

        inline static int signal_pin_pressed(int pin) 
        {
            return gpio_get(pin);
        }

    # else

        static int signal_pin_initialize(int pin) 
        {
          //pinMode(pin, INPUT_PULLDOWN);
            pinMode(pin, INPUT_PULLUP);
            return 1;
        }

        inline static int signal_pin_pressed(int pin) 
        {
            return ! digitalRead(pin);
        }

    # endif

    int signal_button_initialize()
    {
        signal_pin_initialize(PIO_USEDBUTTONPIN_LEFT);
        signal_pin_initialize(PIO_USEDBUTTONPIN_RIGHT);
        return 1;
    }

    int signal_button_pressed(int what)
    {
        int pin = 0; 
        switch (what) {
            case signal_button_left : pin = PIO_USEDBUTTONPIN_LEFT ; break;
            case signal_button_right: pin = PIO_USEDBUTTONPIN_RIGHT; break;
        }
        if (pin && signal_pin_pressed(pin)) {
            do {
                delay(BOUNCE_DELAY); /* get rid of dender */
            } while (signal_pin_pressed(pin)); 
            return 1;
        } else { 
            return 0;
        }
    }

    typedef enum signal_menu_items { 
        signal_menu_item_palette,
        signal_menu_item_preroll,
        signal_menu_item_dimming,
        signal_menu_item_defaults,
        signal_menu_item_logo,
        signal_menu_item_accesspoint,
        signal_menu_item_address,
        signal_menu_item_save,
        signal_menu_item_restart,
        signal_menu_item_exit,
        /* */
        signal_menu_item_count
    } signal_menu_items;

    static void signal_leds_just_one(int n, CRGB color)
    {
       signal_leds_all(signal_currentstatus->colors.reset, 0);
       signal_leds_set_single(n, color);
       signal_leds_update(signal_leds_on);
    }

    static void signal_button_loop(void)
    {
       int choice = signal_menu_item_palette;
       /* or maybe set a segment */
       signal_leds_just_one(2*choice + 1, signal_currentstatus->colors.green);
       while (1) { 
            if (signal_button_pressed(signal_button_right)) {
                choice = ++choice % signal_menu_item_count;
                signal_leds_just_one(2*choice + 1, 
                    choice == signal_menu_item_exit 
                  ? signal_currentstatus->colors.red
                  : choice == signal_menu_item_save 
                  ? signal_currentstatus->colors.blue
                  : (choice == signal_menu_item_accesspoint || choice == signal_menu_item_address) 
                  ? signal_currentstatus->colors.magenta
                  : signal_currentstatus->colors.green
                );
                delay(200);
            }
            if (signal_button_pressed(signal_button_left)) {
                switch(choice) { 
                    case signal_menu_item_palette:
                        signal_leds_next_palette();
                        break;
                    case signal_menu_item_preroll:
                        signal_leds_preroll();
                        break;
                    case signal_menu_item_dimming:
                        signal_leds_update(signal_configuration->dimming == LED_BRIGHTNESSMIN ? signal_leds_max : signal_leds_down);
                        signal_leds_preroll();                    
                        break;
                    case signal_menu_item_defaults:
                        /* ask for confirmation */
                        /* maybe keep it when configured */
                        signal_configuration->palette = 0; 
                        signal_settings_reset();
                     /* signal_leds_setcolors(); */ /* less */
                        signal_leds_preroll();                    
                        break;
                    case signal_menu_item_logo:
                        signal_leds_show_string("CONTEXT", signal_currentstatus->colors.blue, signal_currentstatus->colors.reset, 2000);
                        break; 
                    case signal_menu_item_accesspoint:
                        signal_wifi_accesspoint();
                        return;
                    case signal_menu_item_address:
                        signal_wifi_address();
                        return;
                    case signal_menu_item_save:
                        signal_settings_save();
                    case signal_menu_item_restart:
# if SIGNAL_USE_DEVICE == ESP32
                        ESP.restart();
# endif 
                        return;
                    case signal_menu_item_exit:
                        return;
                }
             //   delay(200);
                signal_leds_just_one(2*choice + 1, 
                    choice == signal_menu_item_exit 
                  ? signal_currentstatus->colors.red
                  : signal_currentstatus->colors.green
                );
            }
        }
    }

    int signal_button_processed(void) 
    {
        if (signal_button_pressed(signal_button_left)) {
            if (signal_currentstatus->issaved) { 
                signal_leds_turn_on();
            } else { 
                signal_leds_turn_off();
            }
            return 1;
        } 
        if (signal_button_pressed(signal_button_right)) {
           signal_button_loop();
           signal_leds_turn_off();
            return 1;
        } 
        return 0;
    }

# else 

    int signal_button_initialize()
    {
        return 0;
    }

    int signal_button_pressed(int what)
    {
        return 0;
    }

    int signal_button_processed(void) 
    {
        return 0;
    }

# endif
