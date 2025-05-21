
function rX r = {
    match r {
        0b00000 =>  /**/ EXTZ(0x0),
        0b00001 => /**/
            EXTZ(0x1),
        0b00001 => {
            /**/
            EXTZ(0x1)
        },
        _ =>
            //
            Xs[unsigned(r)],
    }
}
