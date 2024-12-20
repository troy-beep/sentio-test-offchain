local json = require('json')
if not Balances then
    Balances = {
        [ao.id] = 10000
    }
end

if Name ~= 'KRISH' then
    Name = 'KRISH'
end




if Ticker ~= 'KRI$H' then
    Ticker = 'KRI$H'
end

if Denomination ~= 10 then
    Denomination = 4
end

if not Logo then
    Logo = 'C2BGfeVNiP3XSnWQe1sNr9Rmz4NYlqfN5xvsQfnipsQ'
end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send({
        Target = msg.From,
        Tags = {
            Name = Name,
            Ticker = Ticker,
            Logo = Logo,
            Denomination = tostring(Denomination)
        }
    })
end)

Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local bal = '0'

    if (msg.Tags.Target and Balances[msg.Tags.Target]) then
        bal = tostring(Balances[msg.Tags.Target])
    elseif Balances[msg.From] then
        bal = tostring(Balances[msg.From])
    end

    ao.send({
        Target = msg.From,
        Tags = {
            Target = msg.From,
            Balance = bal,
            Ticker = Ticker,
            Data = json.encode(tonumber(bal))
        }
    })
end)

Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'), function(msg)
    ao.send({
        Target = msg.From,
        Data = json.encode(Balances)
    })
end)

Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    if not Balances[msg.From] then
        Balances[msg.From] = 0
    end

    if not Balances[msg.Tags.Recipient] then
        Balances[msg.Tags.Recipient] = 0
    end

    local qty = tonumber(msg.Tags.Quantity)
    assert(type(qty) == 'number', 'qty must be number')

    if Balances[msg.From] >= qty then
        Balances[msg.From] = Balances[msg.From] - qty
        Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

        if not msg.Tags.Cast then
            local debitNotice = {
                Target = msg.From,
                Action = 'Debit-Notice',
                Recipient = msg.Recipient,
                Quantity = tostring(qty),
                Data = Colors.gray .. "You transferred " .. Colors.blue .. msg.Quantity .. Colors.gray .. " to " ..
                    Colors.green .. msg.Recipient .. Colors.reset
            }
            local creditNotice = {
                Target = msg.Recipient,
                Action = 'Credit-Notice',
                Sender = msg.From,
                Quantity = tostring(qty),
                Data = Colors.gray .. "You received " .. Colors.blue .. msg.Quantity .. Colors.gray .. " from " ..
                    Colors.green .. msg.From .. Colors.reset
            }

            for tagName, tagValue in pairs(msg) do
                if string.sub(tagName, 1, 2) == "X-" then
                    debitNotice[tagName] = tagValue
                    creditNotice[tagName] = tagValue
                end
            end

            ao.send(debitNotice)
            ao.send(creditNotice)
        end
    else
        ao.send({
            Target = msg.Tags.From,
            Tags = {
                Action = 'Transfer-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Insufficient Balance!'
            }
        })
    end
end)

Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg, env)
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    if msg.From == env.Process.Id then
        local qty = tonumber(msg.Tags.Quantity)
        Balances[env.Process.Id] = Balances[env.Process.Id] + qty
    else
        ao.send({
            Target = msg.Tags.From,
            Tags = {
                Action = 'Mint-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!'
            }
        })
    end
end)


Handlers.add('burn', Handlers.utils.hasMatchingTag('Action', 'Burn'), function(msg)
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')

    Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

        ao.send({
            Target = msg.From,
            Data = Colors.gray .. "Successfully burned " .. msg.Quantity .. " " .. Ticker .. " tokens." .. Colors.reset
        })
    end)
