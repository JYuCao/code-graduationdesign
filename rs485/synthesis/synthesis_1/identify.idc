device jtagport builtin
iice new {IICE} -type regular
iice controller -iice {IICE} none
iice sampler -iice {IICE} -depth 128

signals add -iice {IICE} -silent -trigger -sample  {/Rx_Done}\
{/baud_set}\
{/data_to_send}\
{/received_data}\
{/send_en}\
{/uart_byte_rx/nedege}\
{/uart_byte_rx/rx}\
{/uart_byte_tx/tx}
iice clock -iice {IICE} -edge positive {/sys_clk}

