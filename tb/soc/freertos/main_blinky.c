/*
 * FreeRTOS V202212.00
 * Copyright (C) 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * https://www.FreeRTOS.org
 * https://github.com/FreeRTOS
 *
 */

#include <FreeRTOS.h>
#include <task.h>
#include <queue.h>
#include <stdio.h>
#include <string.h>

#define mainQUEUE_RECEIVE_TASK_PRIORITY    ( tskIDLE_PRIORITY + 2 )
#define mainQUEUE_SEND_TASK_PRIORITY       ( tskIDLE_PRIORITY + 1 )
#define mainQUEUE_SEND_FREQUENCY_MS        pdMS_TO_TICKS( 1 )
#define mainQUEUE_LENGTH                   ( 1000 )

/* A temporary location in the ram used for communication with cocotb */
#define PRINT_LOC ((char *) 0x8002FFF8UL)

int xGetCoreID( void ) {
	int id;
	__asm ( "csrr %0, mhartid" : "=r" ( id ) );
	return id;
}

void vSendString( const char *s ) {
	portENTER_CRITICAL();
  while ( *s ) {
    *PRINT_LOC = *s;
    s ++;
  }
	portEXIT_CRITICAL();
}

void handle_trap( void ) {
	while (1)
		;
}

static QueueHandle_t xQueue = NULL;

static void prvQueueSendTask( void * pvParameters ) {
    TickType_t xNextWakeTime;
    unsigned long ulValueToSend = 0UL;

    ( void ) pvParameters;

    xNextWakeTime = xTaskGetTickCount();

    for( ; ; ) {
        vTaskDelayUntil( &xNextWakeTime, mainQUEUE_SEND_FREQUENCY_MS );

        ulValueToSend++;

        char buf[ 40 ];
        sprintf( buf, "%d: %s: send %ld\n", xGetCoreID(),
                 pcTaskGetName( xTaskGetCurrentTaskHandle() ),
                 ulValueToSend );
        vSendString( buf );

        xQueueSend( xQueue, &ulValueToSend, 0U );
        if (ulValueToSend == 7) {
            __asm volatile ("ebreak");
        }
    }
}

static void prvQueueReceiveTask( void * pvParameters ) {
    ( void ) pvParameters;

    for( ; ; ) {
        unsigned long ulReceivedValue;

        xQueueReceive( xQueue, &ulReceivedValue, portMAX_DELAY );

        char buf[ 40 ];
        sprintf( buf, "%d: %s: received %ld\n", xGetCoreID(),
                 pcTaskGetName( xTaskGetCurrentTaskHandle() ),
                 ulReceivedValue );
        vSendString( buf );
    }
}

int main_blinky( void ) {
    vSendString( "Hello FreeRTOS!\n" );

    xQueue = xQueueCreate( mainQUEUE_LENGTH, sizeof( unsigned long ) );

    if( xQueue != NULL ) {
        xTaskCreate( prvQueueReceiveTask, "Rx", configMINIMAL_STACK_SIZE * 2U, NULL,
                     mainQUEUE_RECEIVE_TASK_PRIORITY, NULL );
        xTaskCreate( prvQueueSendTask, "Tx", configMINIMAL_STACK_SIZE * 2U, NULL,
                     mainQUEUE_SEND_TASK_PRIORITY, NULL );
    }

    vTaskStartScheduler();

    return 0;
}
