# Tikky SampleLock

A lock simulator. The purpose is to demonstrate how digital keys can be received from a message broker, and how the lock communicates lock/unlock operations to the lock vendor's backend.

A message broker is typically used for all communication between physical locks (or their gateways) and the lock vendor's backend. This decouples the lock/gateway from the backend, and allows the lock/gateway to receive commands without having to poll the backend or having to use websockets. It also frees both the lock/gateway and the backend from having to re-send messages, since the message broker acts as a store-and-forward mechanism.

## Setup

Add AMQP_URL as an environment variable: this can be done in the Edit Scheme menu. The AMQP_URL variable can be set to any AMQP server, for example:

    amqp://user:pass@lark.rmq.cloudamqp.com/scxqdlhy

## Function
Each running instance of the lock has its own unique lockID. The lock connects to the AMQP broker and sets up a topography as follows:

    Exchange: "sample.x"
    Bindings: "remove.<lockID>" and "add.<lockID>"
    Published messages have routing key "state.<lockID>"

When the lock receives a message with routing key "add.*", then the payload is the pincode that should replace the lock's current pincode.

When the lock receives a message with routing key "remove.*", then the lock should delete its current pincode.

When the lock is locked or unlocked (with the lock's current pincode) then the lock publishes a message with the payload "lock" or "unlock".