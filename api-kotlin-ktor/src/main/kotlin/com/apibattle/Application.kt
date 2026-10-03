package com.apibattle

import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.ApplicationStopped
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.plugins.swagger.swaggerUI
import io.ktor.server.request.receiveText
import io.ktor.server.response.respond
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import io.ktor.server.routing.routing
import kotlinx.serialization.json.Json

fun main() {
    val config = Config.fromEnv()
    embeddedServer(Netty, port = config.port, host = "0.0.0.0") {
        val dataSource = connectDatabase(config.db)
        monitor.subscribe(ApplicationStopped) { dataSource.close() }
        module()
    }.start(wait = true)
}

fun Application.module() {
    install(ContentNegotiation) {
        json(Json { explicitNulls = true })
    }
    install(StatusPages) {
        exception<ApiException> { call, e ->
            call.respond(e.status, ErrorResponse(e.message ?: ""))
        }
        // Anything unexpected is logged and hidden behind a generic 500.
        exception<Throwable> { call, e ->
            call.application.environment.log.error("request failed", e)
            call.respond(HttpStatusCode.InternalServerError, ErrorResponse("internal server error"))
        }
        status(HttpStatusCode.NotFound) { call, _ ->
            call.respond(HttpStatusCode.NotFound, ErrorResponse("not found"))
        }
    }

    val spec = this::class.java.classLoader.getResource("openapi.yaml")!!.readText()

    routing {
        get("/health") {
            call.respondText("ok", ContentType.Text.Plain)
        }
        get("/openapi.yaml") {
            call.respondText(spec, ContentType.parse("application/yaml"))
        }
        swaggerUI(path = "docs", swaggerFile = "openapi.yaml")

        route("/accounts") {
            get {
                val p = Pagination.parse(call.request.queryParameters["page"], call.request.queryParameters["page_size"])
                call.respond(LedgerService.listAccounts(p))
            }
            get("/{id}") {
                call.respond(LedgerService.getAccount(parseId(call.parameters["id"])))
            }
            get("/{id}/transactions") {
                val id = parseId(call.parameters["id"])
                val p = Pagination.parse(call.request.queryParameters["page"], call.request.queryParameters["page_size"])
                call.respond(LedgerService.listTransactions(id, p))
            }
            post("/{id}/transactions") {
                val id = parseId(call.parameters["id"])
                val input = parseNewTransaction(call.receiveText())
                call.respond(HttpStatusCode.Created, LedgerService.addTransaction(id, input))
            }
        }

        get("/transactions/{id}") {
            call.respond(LedgerService.getTransaction(parseId(call.parameters["id"])))
        }
    }
}
